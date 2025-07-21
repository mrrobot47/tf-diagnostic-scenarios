terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
}

# Enable all necessary APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "sqladmin.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_network" "test_vpc" {
  name                    = "test-sc-5-network"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "test_subnet" {
  name          = "test-sc-5-subnet"
  ip_cidr_range = "10.8.0.0/24"
  region        = var.region
  network       = google_compute_network.test_vpc.id
}

# Add Cloud NAT for internet access
resource "google_compute_router" "test_router" {
  name    = "test-sc-5-router"
  region  = var.region
  network = google_compute_network.test_vpc.id
}

resource "google_compute_router_nat" "test_nat" {
  name   = "test-sc-5-nat"
  router = google_compute_router.test_router.name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_global_address" "test_sc_5_private_ip" {
  name          = "test-sc-5-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.test_vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.test_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.test_sc_5_private_ip.name]
}

resource "google_sql_database_instance" "test_db" {
  name             = "test-sc-5-db"
  region           = var.region
  database_version = "POSTGRES_14"
  settings {
    tier = "db-g1-small"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.test_vpc.id
    }
  }
  deletion_protection = false
  depends_on          = [google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_user" "test_user" {
  name     = "postgres"
  instance = google_sql_database_instance.test_db.name
  password = "test123"
}

resource "google_service_account" "test_sa" {
  account_id   = "test-sc-5-sa"
  display_name = "Test Scenario 5 Service Account"
}

resource "google_project_iam_member" "sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.test_sa.email}"
}

resource "google_cloud_run_v2_service" "test_service" {
  name     = "test-sc-5-sql-direct-connect"
  location = var.region

  template {
    service_account = google_service_account.test_sa.email
    
    # Direct VPC Egress configuration
    vpc_access {
      network_interfaces {
        network    = google_compute_network.test_vpc.id
        subnetwork = google_compute_subnetwork.test_subnet.id
        tags       = ["cloud-run-service"]
      }
      egress = "ALL_TRAFFIC"
    }

    containers {
      image = "gcr.io/google.com/cloudsdktool/google-cloud-cli:alpine"
      command = ["/bin/sh", "-c"]
      args = [
        <<-EOF
        apk add --no-cache postgresql-client python3 &&
        echo "--- Starting Cloud SQL connectivity test ---" &&
        if PGPASSWORD=test123 psql -h ${google_sql_database_instance.test_db.private_ip_address} -p 5432 -U postgres -d postgres -c "SELECT 1 as test_connection;" > /tmp/sql_result.log 2>&1; then
          echo "--- SUCCESS: Connected to Cloud SQL via Direct VPC Egress ---"
          STATUS="✅ SUCCESS"
          DETAILS="Successfully connected to Cloud SQL (${google_sql_database_instance.test_db.private_ip_address}:5432) via Direct VPC Egress and executed SELECT 1."
          CLASS="success"
        else
          echo "--- FAILURE: Could not connect to Cloud SQL ---"
          STATUS="❌ FAILURE"
          DETAILS="Could not connect to Cloud SQL. Error: $(cat /tmp/sql_result.log)"
          CLASS="failure"
        fi &&
        
        python3 -c "
import http.server
import socketserver
import datetime

class TestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        html = '''<!DOCTYPE html>
<html>
<head>
    <title>Scenario 5: Cloud Run + Cloud SQL Test</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .success { color: #28a745; }
        .failure { color: #dc3545; }
        .status { font-size: 28px; font-weight: bold; margin: 20px 0; }
        .details { background: #f8f9fa; padding: 20px; border-radius: 4px; margin: 20px 0; font-family: monospace; }
        .info { font-size: 14px; color: #666; margin-top: 20px; line-height: 1.6; }
    </style>
</head>
<body>
    <div class=\"container\">
        <h1>🧪 Scenario 5: Cloud Run + Cloud SQL (Direct VPC Egress)</h1>
        <div class=\"status CLASS_PLACEHOLDER\">STATUS_PLACEHOLDER</div>
        <div class=\"details\">DETAILS_PLACEHOLDER</div>
        <div class=\"info\">
            <strong>🔧 Architecture Tested:</strong><br>
            • Cloud Run service with Direct VPC Egress<br>
            • Private Cloud SQL PostgreSQL (no public IP)<br>
            • VPC network with /24 subnet<br>
            • Private Service Access connection<br>
            • IAM service account with Cloud SQL client role<br><br>
            <strong>📋 Test Method:</strong> Real psql connection from Cloud Run to Cloud SQL<br>
            <strong>⏱️ Test Time:</strong> ''' + str(datetime.datetime.now()) + '''
        </div>
    </div>
</body>
</html>'''
        html = html.replace('STATUS_PLACEHOLDER', '$STATUS')
        html = html.replace('DETAILS_PLACEHOLDER', '$DETAILS')
        html = html.replace('CLASS_PLACEHOLDER', '$CLASS')
        
        self.send_response(200)
        self.send_header('Content-type', 'text/html')
        self.end_headers()
        self.wfile.write(html.encode())

print('Starting HTTP server on port 8080...')
with socketserver.TCPServer(('', 8080), TestHandler) as httpd:
    httpd.serve_forever()
"
        EOF
      ]
      env {
        name  = "PGPASSWORD"
        value = "test123"
      }
      ports {
        container_port = 8080
      }
    }
  }
  depends_on = [google_project_iam_member.sql_client]
}
