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

resource "google_project_service" "vpc_access_api" {
  project = var.project_id
  service = "vpcaccess.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "vpc_connector_network" {
  name                    = "test-sc-3-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vpc_connector_subnet" {
  name          = "test-sc-3-subnet"
  ip_cidr_range = "10.8.0.0/28" # Required range for VPC connectors
  region        = var.region
  network       = google_compute_network.vpc_connector_network.id
}

resource "google_vpc_access_connector" "serverless_vpc_connector" {
  name    = "test-sc-3-connector"
  region  = var.region
  subnet {
    name = google_compute_subnetwork.vpc_connector_subnet.name
  }
  machine_type = "e2-micro"

  depends_on = [google_project_service.vpc_access_api]
}
