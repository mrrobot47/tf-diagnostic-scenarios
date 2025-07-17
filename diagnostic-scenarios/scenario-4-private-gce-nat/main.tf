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

resource "google_compute_network" "test_vpc" {
  name                    = "nat-test-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "test_subnet" {
  name                     = "nat-test-subnet"
  ip_cidr_range            = "10.0.10.0/24"
  region                   = var.region
  network                  = google_compute_network.test_vpc.id
  private_ip_google_access = true
}

resource "google_compute_router" "test_router" {
  name    = "nat-test-router"
  region  = var.region
  network = google_compute_network.test_vpc.id
}

resource "google_compute_router_nat" "test_nat" {
  name                               = "nat-test-gateway"
  router                             = google_compute_router.test_router.name
  region                             = var.region
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  nat_ip_allocate_option             = "AUTO_ONLY"

  subnetwork {
    name                    = google_compute_subnetwork.test_subnet.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  depends_on = [google_compute_router.test_router]
}

resource "google_compute_instance" "test_vm" {
  name         = "nat-test-vm"
  machine_type = "e2-micro"
  zone         = var.zone
  tags         = ["private-vm"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
    }
  }

  # This instance has no public IP address
  network_interface {
    network    = google_compute_network.test_vpc.id
    subnetwork = google_compute_subnetwork.test_subnet.id
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    # Try to reach an external service
    echo "--- Testing outbound connectivity ---"
    if curl -sS --fail https://www.google.com > /dev/null; then
      echo "--- SUCCESS: Hello from Google! ---"
    else
      echo "--- FAILURE: Could not connect to external service. ---"
      exit 1
    fi
  EOT

  # Allow terraform to re-create the instance if the script changes
  lifecycle {
    create_before_destroy = true
  }

  depends_on = [google_compute_router_nat.test_nat]
}
