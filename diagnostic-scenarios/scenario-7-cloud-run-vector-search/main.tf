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

resource "google_vertex_ai_index_endpoint" "vertex_endpoint" {
  display_name            = "test-sc-7-endpoint"
  region                  = var.region
  public_endpoint_enabled = false
  network                 = google_compute_network.vpc.id
  depends_on = [google_project_service.apis]
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
      image   = "gcr.io/google.com/cloudsdktool/google-cloud-cli:slim"
      command = ["/bin/bash", "-c"]
      args = [
        <<-EOT
          apt-get update && apt-get install -y python3-pip && pip3 install google-cloud-aiplatform
          python3 -c "
import os
import sys
from google.cloud import aiplatform

print('--- Attempting to connect to Vertex AI Vector Search Endpoint ---')

project_id = os.environ.get('PROJECT_ID')
region = os.environ.get('REGION')
endpoint_id = os.environ.get('ENDPOINT_ID')

try:
    aiplatform.init(project=project_id, location=region)
    endpoint = aiplatform.MatchingEngineIndexEndpoint(endpoint_name=endpoint_id)
    print(f'--- SUCCESS: Successfully initialized client and found Vertex AI Index Endpoint: {endpoint.display_name} ---')
    with open('index.html', 'w') as f:
        f.write('<h1>SUCCESS: Successfully initialized client and found Vertex AI Index Endpoint</h1>')
except Exception as e:
    print(f'--- FAILURE: Could not connect to Vertex AI Endpoint. Error: {e} ---', file=sys.stderr)
    with open('index.html', 'w') as f:
        f.write(f'<h1>FAILURE: Could not connect to Vertex AI Endpoint. Error: {e}</h1>')
"
          python3 -m http.server 8080
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
    }
  }
  depends_on = [google_project_iam_member.vertex_ai_user, google_vertex_ai_index_endpoint.vertex_endpoint]
}
