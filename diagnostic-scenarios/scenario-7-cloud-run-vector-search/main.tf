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

resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "aiplatform.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_network" "vpc" {
  name                    = "test-sc-7-network"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "cloudrun_subnet" {
  name                     = "test-sc-7-subnet"
  ip_cidr_range            = "10.8.0.0/24"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  private_ip_google_access = true # CRITICAL for this test
}

resource "google_compute_router" "nat_router" {
  name    = "test-sc-7-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name   = "test-sc-7-nat"
  router = google_compute_router.nat_router.name
  region = var.region

  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_storage_bucket" "vertex_index_bucket" {
  name          = "test-sc-7-index-bucket"
  location      = var.region
  force_destroy = true
}

resource "google_vertex_ai_index" "test_index" {
  display_name = "test-sc-7-index"
  region       = var.region
  metadata {
    contents_delta_uri = "gs://${google_storage_bucket.vertex_index_bucket.name}"
    config {
      dimensions              = 1
      approximate_neighbors_count = 5
      distance_measure_type   = "DOT_PRODUCT_DISTANCE"
      algorithm_config {
        tree_ah_config {
          leaf_node_embedding_count = 500
          leaf_nodes_to_search_percent = 7
        }
      }
    }
  }
  depends_on = [google_project_service.apis]
}

data "google_project" "project" {}

resource "google_service_networking_connection" "peering" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.vertex_peering_range.name]
}

resource "google_compute_global_address" "vertex_peering_range" {
  name          = "test-sc-7-peering-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 24
  network       = google_compute_network.vpc.id
}

resource "google_vertex_ai_index_endpoint" "vertex_endpoint" {
  display_name            = "test-sc-7-endpoint"
  region                  = var.region
  public_endpoint_enabled = false
  network                 = "projects/${data.google_project.project.number}/global/networks/${google_compute_network.vpc.name}"
  depends_on = [google_project_service.apis, google_service_networking_connection.peering]
}

resource "google_service_account" "cloudrun_sa" {
  account_id   = "test-sc-7-sa"
  display_name = "Test Scenario 7 Service Account"
}

resource "google_project_iam_member" "vertex_ai_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

resource "google_cloud_run_v2_service" "cloudrun_vector_search_connectivity_tester" {
  name     = "test-sc-7-vector-search-connect"
  location = var.region

  template {
    service_account = google_service_account.cloudrun_sa.email
    vpc_access {
      network_interfaces {
        network    = google_compute_network.vpc.id
        subnetwork = google_compute_subnetwork.cloudrun_subnet.id
      }
      egress = "ALL_TRAFFIC"
    }
    containers {
      image   = "gcr.io/google.com/cloudsdktool/google-cloud-cli:alpine"
      command = ["/bin/sh", "-c"]
      args = [
        <<-EOT
        # Step 1: Install dependencies
        apk add --no-cache python3 py3-pip && python3 -m pip install --no-cache-dir --break-system-packages google-cloud-aiplatform

        # Step 2: Run connectivity test and capture result
        echo "--- Running Vertex AI Connectivity Test ---"
        python3 -c "
import os, sys
from google.cloud import aiplatform
try:
    aiplatform.init(project=os.environ.get('PROJECT_ID'), location=os.environ.get('REGION'))
    endpoint = aiplatform.MatchingEngineIndexEndpoint(index_endpoint_name=os.environ.get('ENDPOINT_ID'))
    print(f'Successfully found endpoint: {endpoint.display_name}')
    sys.exit(0)
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" > /tmp/vertex_result.log 2>&1

        # Step 3: Set and export status variables based on test result
        if [ $? -eq 0 ]; then
          echo "--- SUCCESS: Connected to Vertex AI ---"
          export STATUS="✅ SUCCESS"
          export DETAILS=$(cat /tmp/vertex_result.log)
          export CLASS="success"
        else
          echo "--- FAILURE: Could not connect to Vertex AI ---"
          export STATUS="❌ FAILURE"
          export DETAILS=$(cat /tmp/vertex_result.log)
          export CLASS="failure"
        fi

        # Step 4: Start the Python HTTP server
        python3 -c "
import http.server
import socketserver
import datetime
import os

class TestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Read status from environment variables
        status = os.environ.get('STATUS', 'Unknown Status')
        details = os.environ.get('DETAILS', 'No details available.')
        css_class = os.environ.get('CLASS', '')

        html = f'''<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Scenario 7: Cloud Run + Vertex AI Connectivity</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }}
        .container {{ max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        .success {{ color: #28a745; }}
        .failure {{ color: #dc3545; }}
        .status {{ font-size: 28px; font-weight: bold; margin: 20px 0; }}
        .details {{ background: #f8f9fa; padding: 20px; border-radius: 4px; margin: 20px 0; font-family: monospace; white-space: pre-wrap; word-wrap: break-word; }}
        .info {{ font-size: 14px; color: #666; margin-top: 20px; line-height: 1.6; }}
    </style>
</head>
<body>
    <div class=\"container\">
        <h1> Scenario 7: Cloud Run + Vertex AI (VPC Peering)</h1>
        <div class=\"status {css_class}\">{status}</div>
        <div class=\"details\">{details}</div>
        <div class=\"info\">
            <strong> Architecture Tested:</strong><br>
            • Cloud Run service with VPC Egress<br>
            • Vertex AI Index Endpoint with a private endpoint<br>
            • VPC network with a dedicated subnet<br>
            • VPC Peering between the VPC and Vertex AI services<br><br>
            <strong> Test Method:</strong> Real connection attempt from Cloud Run to the Vertex AI private endpoint.<br>
            <strong>⏱️ Test Time:</strong> {datetime.datetime.now()}
        </div>
    </div>
</body>
</html>'''

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
      env {
        name = "PROJECT_ID"
        value = var.project_id
      }
      env {
        name = "REGION"
        value = var.region
      }
      env {
        name = "ENDPOINT_ID"
        value = google_vertex_ai_index_endpoint.vertex_endpoint.name
      }
      ports {
        container_port = 8080
      }
      startup_probe {
        timeout_seconds   = 240
        period_seconds    = 240
        failure_threshold = 1
        tcp_socket {
          port = 8080
        }
      }
      resources {
        limits = {
          "cpu"    = "1000m"
          "memory" = "1Gi"
        }
      }
    }
  }
  depends_on = [google_project_iam_member.vertex_ai_user, google_vertex_ai_index_endpoint.vertex_endpoint]
}
