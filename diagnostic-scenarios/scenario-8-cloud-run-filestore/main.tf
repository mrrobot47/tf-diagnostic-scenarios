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
    "file.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

resource "google_compute_network" "vpc" {
  name                    = "test-sc-8-network"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "cloudrun_subnet" {
  name          = "test-sc-8-subnet"
  ip_cidr_range = "10.8.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}
resource "google_compute_global_address" "private_ip_google_services" {
  name          = "test-sc-8-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_google_services.name]
  deletion_policy         = "ABANDON"
  depends_on              = [google_compute_subnetwork.cloudrun_subnet]
}
resource "google_compute_router" "nat_router" {
  name    = "test-sc-8-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "test-sc-8-nat-gateway"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  nat_ip_allocate_option             = "AUTO_ONLY"
  subnetwork {
    name                    = google_compute_subnetwork.cloudrun_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_filestore_instance" "filestore_instance" {
  name     = "test-sc-8-nfs"
  location = var.zone # Filestore is a zonal resource
  tier     = "BASIC_HDD"

  file_shares {
    capacity_gb = 1024 # Minimum for BASIC_HDD tier
    name        = "data"
  }

  networks {
    network = google_compute_network.vpc.id
    modes   = ["MODE_IPV4"]
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_service_account" "cloudrun_sa" {
  account_id   = "test-sc-8-sa"
  display_name = "Test Scenario 8 Service Account"
}

resource "google_cloud_run_v2_service" "cloudrun_filestore_connectivity_tester" {
  name     = "test-sc-8-filestore-mount"
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

    volumes {
      name = "nfs-data-volume"
      nfs {
        server    = google_filestore_instance.filestore_instance.networks[0].ip_addresses[0]
        path      = "/data"
        read_only = false
      }
    }

    containers {
      image = "python:3.9-slim"

      volume_mounts {
        name       = "nfs-data-volume"
        mount_path = "/mnt/data"
      }

      command = ["/bin/bash", "-c"]
      args = [
        <<-EOT
        # Step 1: Test writing to the NFS mount
        TEST_FILE="/mnt/data/test-$(date +%s).txt"
        echo "Hello from Cloud Run at $(date)" > $TEST_FILE

        # Step 2: Verify the write and set status
        if [ -s "$TEST_FILE" ]; then
          echo "--- SUCCESS: File written to NFS mount successfully ---"
          export STATUS="✅ SUCCESS"
          FILE_CONTENT=$(cat $TEST_FILE)
          FILE_LIST=$(ls -l /mnt/data)
          export DETAILS="<p>Successfully wrote to <strong>$TEST_FILE</strong>.</p><p>Content:</p><pre>$FILE_CONTENT</pre><p>Full Directory Listing:</p><pre>$FILE_LIST</pre>"
          export CLASS="success"
          rm $TEST_FILE # Clean up
        else
          echo "--- FAILURE: Could not write to NFS mount ---"
          export STATUS="❌ FAILURE"
          export DETAILS="Failed to write test file to /mnt/data. Check NFS mount configuration and permissions."
          export CLASS="failure"
        fi

        # Step 3: Create and start the Python HTTP server
        cat <<EOF > /server.py
import http.server
import socketserver
import datetime
import os

class TestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        status = os.environ.get('STATUS', 'Unknown Status')
        details = os.environ.get('DETAILS', 'No details available.')
        css_class = os.environ.get('CLASS', '')

        html = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>Scenario 8: Cloud Run + Filestore Connectivity</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }}
        .container {{ max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        .success {{ color: #28a745; }}
        .failure {{ color: #dc3545; }}
        .status {{ font-size: 28px; font-weight: bold; margin: 20px 0; }}
        .details {{ background: #f8f9fa; padding: 20px; border-radius: 4px; margin: 20px 0; font-family: monospace; white-space: pre-wrap; word-wrap: break-word; }}
        .info {{ font-size: 14px; color: #666; margin-top: 20px; line-height: 1.6; }}
        pre {{ white-space: pre-wrap; word-wrap: break-word; }}
    </style>
</head>
<body>
    <div class="container">
        <h1> Scenario 8: Cloud Run + Filestore (NFS Mount)</h1>
        <div class="status {css_class}">{status}</div>
        <div class="details">{details}</div>
        <div class="info">
            <strong> Architecture Tested:</strong><br>
            • Cloud Run service with a mounted NFS volume<br>
            • Filestore instance on the same VPC<br>
            • VPC network with a dedicated subnet<br>
            • Private Service Access connection for Filestore<br><br>
            <strong> Test Method:</strong> Attempting to write and read a file from the NFS mount within the Cloud Run container.<br>
            <strong>⏱️ Test Time:</strong> {datetime.datetime.now()}
        </div>
    </div>
</body>
</html>'''

        self.send_response(200)
        self.send_header('Content-type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(html.encode('utf-8'))

print('Starting HTTP server on port 8080...')
with socketserver.TCPServer(('', 8080), TestHandler) as httpd:
    httpd.serve_forever()
EOF
        python3 /server.py
        EOT
      ]
    }
  }
  depends_on = [google_filestore_instance.filestore_instance, google_compute_router_nat.nat]
}
