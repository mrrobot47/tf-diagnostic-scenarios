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
    "redis.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_network" "test_vpc" {
  name                    = "test-sc-6-network"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "test_subnet" {
  name          = "test-sc-6-subnet"
  ip_cidr_range = "10.8.0.0/24"
  region        = var.region
  network       = google_compute_network.test_vpc.id
}

# Add Cloud NAT for internet access
resource "google_compute_router" "test_router" {
  name    = "test-sc-6-router"
  region  = var.region
  network = google_compute_network.test_vpc.id
}

resource "google_compute_router_nat" "test_nat" {
  name   = "test-sc-6-nat"
  router = google_compute_router.test_router.name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_global_address" "private_ip_for_google_services" {
  name          = "test-sc-6-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.test_vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.test_vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_for_google_services.name]
  deletion_policy         = "ABANDON"
}

resource "google_redis_instance" "test_redis" {
  name               = "test-sc-6-redis"
  region             = var.region
  tier               = "BASIC"
  memory_size_gb     = 1
  authorized_network = google_compute_network.test_vpc.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"
  depends_on         = [google_service_networking_connection.private_vpc_connection]
}

resource "google_service_account" "test_sa" {
  account_id   = "test-sc-6-sa"
  display_name = "Test Scenario 6 Service Account"
}

resource "google_project_iam_member" "redis_client" {
  project = var.project_id
  role    = "roles/redis.viewer"
  member  = "serviceAccount:${google_service_account.test_sa.email}"
}

resource "google_cloud_run_v2_service" "test_service" {
  name     = "test-sc-6-redis-direct-connect"
  location = var.region

  template {
    service_account = google_service_account.test_sa.email

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
        <<-EOT
          apk add --no-cache redis python3
          echo "--- Starting Redis connectivity test ---"
          if redis-cli -h ${google_redis_instance.test_redis.host} PING | grep -q PONG; then
            echo "--- SUCCESS: Connected to Redis ---"
            STATUS="✅ SUCCESS"
            DETAILS="Successfully connected to Redis (${google_redis_instance.test_redis.host}) and received PONG."
            CLASS="success"
          else
            echo "--- FAILURE: Could not connect to Redis ---"
            STATUS="❌ FAILURE"
            DETAILS="Could not connect to Redis. The host ${google_redis_instance.test_redis.host} was not reachable."
            CLASS="failure"
          fi

          python3 -c "
import http.server
import socketserver
import datetime

class TestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        html = '''<!DOCTYPE html>
<html>
<head>
    <title>Scenario 6: Cloud Run + Redis Test</title>
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
        <h1>🧪 Scenario 6: Cloud Run + Redis (Direct VPC Egress)</h1>
        <div class=\"status CLASS_PLACEHOLDER\">STATUS_PLACEHOLDER</div>
        <div class=\"details\">DETAILS_PLACEHOLDER</div>
        <div class=\"info\">
            <strong>🔧 Architecture Tested:</strong><br>
            • Cloud Run service with Direct VPC Egress & Cloud NAT<br>
            • Private Memorystore for Redis (no public IP)<br>
            • VPC network with /24 subnet<br>
            • Private Service Access connection<br>
            • IAM service account with Redis client role<br><br>
            <strong>📋 Test Method:</strong> Real redis-cli PING from Cloud Run to Redis<br>
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
        EOT
      ]
      ports {
        container_port = 8080
      }
    }
  }
  depends_on = [google_project_iam_member.redis_client]
}