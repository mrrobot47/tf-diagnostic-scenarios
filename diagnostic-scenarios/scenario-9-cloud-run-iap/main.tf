terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.31.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.31.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.1"
    }
  }
}

provider "google" {
  project = var.project_id
}

provider "google-beta" {
  project = var.project_id
}

# Enable the necessary APIs for Cloud Run and IAP
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "iap.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# This resource will wait for 30 seconds after the APIs are enabled
resource "time_sleep" "wait_for_api_propagation" {
  create_duration = "30s"
  depends_on      = [google_project_service.apis]
}

data "google_project" "current" {}

# --- Conditional OAuth Client Creation ---

resource "google_iap_brand" "test_sc_9_brand" {
  count             = var.create_oauth_client ? 1 : 0
  project           = var.project_id
  support_email     = "user:${var.oauth_support_email}"
  application_title = "Test SC-9 IAP"
  depends_on        = [time_sleep.wait_for_api_propagation]
}

resource "google_iap_client" "test_sc_9_client" {
  count        = var.create_oauth_client ? 1 : 0
  display_name = "test-sc-9-iap-client"
  brand        = one(google_iap_brand.test_sc_9_brand).name
}

# --- Cloud Run Service Configuration ---

resource "google_cloud_run_v2_service" "test_sc_9_service" {
  provider = google-beta

  name     = "test-sc-9-iap-hello"
  location = var.region

  deletion_protection = false

  iap_enabled  = true
  launch_stage = "BETA"

  template {
    containers {
      image = "gcr.io/cloudrun/hello"
    }
    labels = {
      "iap-dependency" = var.create_oauth_client ? one(google_iap_client.test_sc_9_client).client_id : "none"
    }
  }
}

# --- IAM Bindings ---

resource "google_iap_web_iam_member" "test_sc_9_user_access" {
  for_each = toset(var.iap_members)
  project  = var.project_id
  role     = "roles/iap.httpsResourceAccessor"
  member   = each.key
  depends_on = [time_sleep.wait_for_api_propagation]
}

resource "google_cloud_run_v2_service_iam_member" "test_sc_9_iap_invoker" {
  provider = google-beta
  project  = google_cloud_run_v2_service.test_sc_9_service.project
  location = google_cloud_run_v2_service.test_sc_9_service.location
  name     = google_cloud_run_v2_service.test_sc_9_service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-iap.iam.gserviceaccount.com"
}
