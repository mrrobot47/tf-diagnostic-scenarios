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

resource "google_compute_network" "test_vpc" {
  name                    = "test-sc-8-network"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "test_subnet" {
  name          = "test-sc-8-subnet"
  ip_cidr_range = "10.8.0.0/24"
  region        = var.region
  network       = google_compute_network.test_vpc.id
}

resource "google_compute_global_address" "private_ip_for_google_services" {
  name          = "test-sc-8-private-ip"
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

resource "google_compute_router" "test_router" {
  name    = "test-sc-8-router"
  region  = var.region
  network = google_compute_network.test_vpc.id
}

resource "google_compute_router_nat" "test_nat" {
  name                               = "test-sc-8-nat-gateway"
  router                             = google_compute_router.test_router.name
  region                             = var.region
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  nat_ip_allocate_option             = "AUTO_ONLY"
  subnetwork {
    name                    = google_compute_subnetwork.test_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_filestore_instance" "test_nfs" {
  name     = "test-sc-8-nfs"
  location = var.zone # Filestore is a zonal resource
  tier     = "BASIC_HDD"

  file_shares {
    capacity_gb = 1024 # Minimum for BASIC_HDD tier
    name        = "data"
  }

  networks {
    network = google_compute_network.test_vpc.id
    modes   = ["MODE_IPV4"]
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_service_account" "test_sa" {
  account_id   = "test-sc-8-sa"
  display_name = "Test Scenario 8 Service Account"
}

resource "google_cloud_run_v2_service" "test_service" {
  name     = "test-sc-8-filestore-mount"
  location = var.region

  template {
    service_account = google_service_account.test_sa.email

    vpc_access {
      network_interfaces {
        network    = google_compute_network.test_vpc.id
        subnetwork = google_compute_subnetwork.test_subnet.id
      }
      egress = "ALL_TRAFFIC"
    }

    volumes {
      name = "nfs-data-volume"
      nfs {
        server    = google_filestore_instance.test_nfs.networks[0].ip_addresses[0]
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
          echo "--- Creating test file in NFS mount ---"
          echo "Hello from Filestore at $(date)" > /mnt/data/test.txt
          
          echo "--- Starting Python HTTP server ---"
          cat <<EOF > /server.py
import http.server
import socketserver
import os

PORT = 8080
MOUNT_PATH = '/mnt/data'

class MyHttpRequestHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            
            html = "<h1>✅ SUCCESS: Filestore Mount Verified</h1>"
            html += "<h2>Contents of /mnt/data:</h2>"
            try:
                files = os.listdir(MOUNT_PATH)
                if not files:
                    html += "<p>Directory is empty.</p>"
                else:
                    html += "<ul>"
                    for file in files:
                        html += f"<li>{file}</li>"
                    html += "</ul>"
            except Exception as e:
                html += f"<p><b>Error reading directory:</b> {e}</p>"
            
            self.wfile.write(bytes(html, "utf8"))
        else:
            super().do_GET()

Handler = MyHttpRequestHandler

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print("serving at port", PORT)
    httpd.serve_forever()
EOF
          python3 /server.py
        EOT
      ]
    }
  }
  depends_on = [google_filestore_instance.test_nfs, google_compute_router_nat.test_nat]
}
