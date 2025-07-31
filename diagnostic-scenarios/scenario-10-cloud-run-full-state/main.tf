terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.31.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

# 1. Enable all necessary APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com", "storage.googleapis.com", "iam.googleapis.com",
    "sqladmin.googleapis.com", "compute.googleapis.com", "servicenetworking.googleapis.com",
    "redis.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# 2. Create the VPC and Subnet
resource "google_compute_network" "vpc" {
  name                    = "test-sc-10-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}
resource "google_compute_subnetwork" "subnet" {
  name          = "test-sc-10-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# 3. Set up Private Service Access for SQL
resource "google_compute_global_address" "private_service_access" {
  name          = "test-sc-10-private-access"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}
resource "google_service_networking_connection" "vpc_peering" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access.name]
  deletion_policy         = "ABANDON"
  depends_on = [google_compute_subnetwork.subnet]
}

# 4. Add Cloud NAT for outbound internet access from the VPC
resource "google_compute_router" "router" {
  name    = "test-sc-10-router"
  region  = var.region
  network = google_compute_network.vpc.id
}
resource "google_compute_router_nat" "nat" {
  name                               = "test-sc-10-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# 5. Provision the GCS bucket
resource "google_storage_bucket" "bucket" {
  name                        = "test-sc-10-bucket-${var.project_id}"
  location                    = var.region
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  depends_on                  = [google_project_service.apis]
}

# 6. Provision the private Cloud SQL (PostgreSQL) instance
resource "google_sql_database_instance" "db" {
  name                = "test-sc-10-postgres-db"
  region              = var.region
  database_version    = "POSTGRES_14"
  deletion_protection = false
  settings {
    tier = "db-g1-small"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }
  }
  depends_on = [google_service_networking_connection.vpc_peering]
}

# Create the database user with proper password attribute
resource "google_sql_user" "test_user" {
  name     = "testuser"
  instance = google_sql_database_instance.db.name
  password = "testpassword123!"
}

# 6.5. Provision the Redis instance
resource "google_redis_instance" "redis_instance" {
  name               = "test-sc-10-redis-instance"
  region             = var.region
  tier               = "BASIC"
  memory_size_gb     = 1
  authorized_network = google_compute_network.vpc.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"
  depends_on         = [google_service_networking_connection.vpc_peering]
}

# 7. Create the dedicated Service Account for Cloud Run
resource "google_service_account" "sa" {
  account_id   = "test-sc-10-run-sa"
  display_name = "Test Scenario 10 Cloud Run SA"
  depends_on   = [google_project_service.apis]
}

# 8. Grant the required IAM permissions
resource "google_project_iam_member" "sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.sa.email}"
}
resource "google_storage_bucket_iam_member" "gcs_access" {
  bucket = google_storage_bucket.bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.sa.email}"
}
resource "google_project_iam_member" "redis_access" {
  project = var.project_id
  role    = "roles/redis.editor"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

# 9. Deploy the Cloud Run test service
resource "google_cloud_run_v2_service" "main_service" {
  name                = "test-sc-10-full-state-tester"
  location            = var.region
  deletion_protection = false

  template {
    service_account = google_service_account.sa.email
    vpc_access {
      network_interfaces {
        network    = google_compute_network.vpc.id
        subnetwork = google_compute_subnetwork.subnet.id
        tags       = ["cloud-run-service"]
      }
      egress = "ALL_TRAFFIC"
    }

    containers {
      image   = "gcr.io/google.com/cloudsdktool/google-cloud-cli:alpine"
      command = ["/bin/sh", "-c"]
      args = [
        <<-EOT
          apk add --no-cache postgresql-client python3 redis
          
          echo "--- Running Tests ---"
          
          # Test GCS access
          echo "Testing GCS access..."
          if gsutil ls gs://${google_storage_bucket.bucket.name} > /tmp/gcs_result.log 2>&1; then 
            export GCS_STATUS="✅ SUCCESS"
            echo "GCS test: SUCCESS"
          else 
            export GCS_STATUS="❌ FAILURE"
            echo "GCS test: FAILURE - $(cat /tmp/gcs_result.log)"
          fi
          
          # Test SQL access
          echo "Testing SQL access..."
          export PGPASSWORD='testpassword123!'
          if PGPASSWORD=testpassword123! psql -h ${google_sql_database_instance.db.private_ip_address} -p 5432 -U testuser -d postgres -c "SELECT 1 as test_connection;" > /tmp/sql_result.log 2>&1; then 
            export SQL_STATUS="✅ SUCCESS"
            echo "SQL test: SUCCESS"
          else 
            export SQL_STATUS="❌ FAILURE"
            echo "SQL test: FAILURE - $(cat /tmp/sql_result.log)"
          fi
          
          # Test Redis access
          echo "Testing Redis access..."
          if redis-cli -h ${google_redis_instance.redis_instance.host} PING > /tmp/redis_result.log 2>&1 && grep -q PONG /tmp/redis_result.log; then
            export REDIS_STATUS="✅ SUCCESS"
            echo "Redis test: SUCCESS"
          else
            export REDIS_STATUS="❌ FAILURE"
            echo "Redis test: FAILURE - $(cat /tmp/redis_result.log)"
          fi
          
          # Export the Terraform-substituted values for Python to use
          export GCS_BUCKET_NAME="${google_storage_bucket.bucket.name}"
          export SQL_HOST_IP="${google_sql_database_instance.db.private_ip_address}"
          export REDIS_HOST_IP="${google_redis_instance.redis_instance.host}"

          echo "--- Starting Web Server ---"
          python3 -c "
import http.server, socketserver, os, datetime
class TestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Read the status and details from the environment
        gcs_status = os.getenv('GCS_STATUS', '⚪ PENDING')
        sql_status = os.getenv('SQL_STATUS', '⚪ PENDING')
        redis_status = os.getenv('REDIS_STATUS', '⚪ PENDING')
        gcs_bucket = os.getenv('GCS_BUCKET_NAME', 'N/A')
        sql_host = os.getenv('SQL_HOST_IP', 'N/A')
        redis_host = os.getenv('REDIS_HOST_IP', 'N/A')

        # Determine CSS classes for styling
        gcs_class = 'success' if '✅' in gcs_status else 'failure' if '❌' in gcs_status else 'pending'
        sql_class = 'success' if '✅' in sql_status else 'failure' if '❌' in sql_status else 'pending'
        redis_class = 'success' if '✅' in redis_status else 'failure' if '❌' in redis_status else 'pending'

        self.send_response(200)
        self.send_header('Content-type', 'text/html; charset=utf-8')
        self.end_headers()
        
        html = f'''<!DOCTYPE html>
<html>
<head>
    <meta charset=\"utf-8\">
    <title>Scenario 10: Full State Test</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }}
        .container {{ max-width: 1000px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        h1 {{ color: #1a73e8; margin-bottom: 30px; }}
        table {{ border-collapse: collapse; width: 100%; background: white; margin: 20px 0; }}
        td, th {{ border: 1px solid #dfe2e5; padding: 15px; text-align: left; }}
        th {{ background: #f1f3f4; font-weight: bold; }}
        .success {{ color: #28a745; font-weight: bold; }}
        .failure {{ color: #dc3545; font-weight: bold; }}
        .pending {{ color: #6c757d; font-weight: bold; }}
        .info {{ font-size: 14px; color: #666; margin-top: 30px; line-height: 1.6; }}
        .status-icon {{ font-size: 18px; }}
    </style>
</head>
<body>
    <div class=\"container\">
        <h1>🧪 Scenario 10: Full State Test</h1>
        <p><strong>Test Time:</strong> {datetime.datetime.now()}</p>
        
        <table>
            <tr>
                <th>Service</th>
                <th>Status</th>
                <th>Details</th>
            </tr>
            <tr>
                <td><strong>Cloud SQL (PostgreSQL)</strong></td>
                <td class=\"{sql_class}\">{sql_status}</td>
                <td>Connection to {sql_host}:5432 as user 'testuser'</td>
            </tr>
            <tr>
                <td><strong>Memorystore (Redis)</strong></td>
                <td class=\"{redis_class}\">{redis_status}</td>
                <td>PING command to {redis_host}:6379</td>
            </tr>
            <tr>
                <td><strong>Cloud Storage (GCS)</strong></td>
                <td class=\"{gcs_class}\">{gcs_status}</td>
                <td>Listing contents of gs://{gcs_bucket}</td>
            </tr>
        </table>
        
        <div class=\"info\">
            <strong>🔧 Architecture Tested:</strong><br>
            • Cloud Run service with Direct VPC Egress<br>
            • Private Cloud SQL PostgreSQL (no public IP)<br>
            • Private Memorystore for Redis (no public IP)<br>
            • Cloud Storage bucket with IAM-based access<br>
            • VPC network with /24 subnet and Cloud NAT<br>
            • Private Service Access connection<br>
            • IAM service account with appropriate roles<br><br>
            <strong>📋 Test Methods:</strong><br>
            • Real psql connection from Cloud Run to Cloud SQL<br>
            • Real redis-cli PING from Cloud Run to Redis<br>
            • Real gsutil command to test GCS access<br>
        </div>
    </div>
</body>
</html>'''
        self.wfile.write(html.encode('utf-8'))

print('Starting HTTP server on port 8080...')
with socketserver.TCPServer(('', 8080), TestHandler) as httpd:
    httpd.serve_forever()
"
        EOT
      ]
      env {
        name  = "PGPASSWORD"
        value = "testpassword123!"
      }
      ports { container_port = 8080 }
    }
  }
  depends_on = [
    google_project_iam_member.sql_client,
    google_storage_bucket_iam_member.gcs_access,
    google_project_iam_member.redis_access,
    google_compute_router_nat.nat
  ]
}

# 10. Allow the specified test user to invoke the service
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  project  = google_cloud_run_v2_service.main_service.project
  location = google_cloud_run_v2_service.main_service.location
  name     = google_cloud_run_v2_service.main_service.name
  role     = "roles/run.invoker"
  member   = "user:${var.test_user_email}"
}
