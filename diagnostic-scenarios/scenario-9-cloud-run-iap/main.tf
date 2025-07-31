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

data "google_client_openid_userinfo" "me" {}
data "google_project" "current" {}

# --- Conditional OAuth Client Creation ---

resource "google_iap_brand" "project_brand" {
  count             = var.create_oauth_client ? 1 : 0
  project           = var.project_id
  support_email     = "user:${data.google_client_openid_userinfo.me.email}"
  application_title = "Cloud Run IAP Diagnostic Test"
  depends_on        = [google_project_service.apis]
}

resource "google_iap_client" "project_client" {
  count        = var.create_oauth_client ? 1 : 0
  display_name = "Cloud Run IAP Test Client"
  brand        = one(google_iap_brand.project_brand).name
}

# --- Cloud Run Service Configuration ---

resource "google_cloud_run_v2_service" "iap_test_service" {
  provider = google-beta

  name     = "test-sc-9-iap-hello"
  location = var.region

  deletion_protection = false

  # Correct syntax from your deployment.zip
  iap_enabled  = true
  launch_stage = "BETA"

  template {
    containers {
      image = "gcr.io/cloudrun/hello"
    }

    labels = {
      "iap-dependency" = var.create_oauth_client ? one(google_iap_client.project_client).client_id : "none"
    }
  }
}

# --- IAM Bindings ---

resource "google_iap_web_iam_member" "user_access" {
  project = var.project_id
  role    = "roles/iap.httpsResourceAccessor"
  member  = "user:${var.test_user_email}"
}

resource "google_cloud_run_v2_service_iam_member" "iap_invoker" {
  provider = google-beta
  project  = google_cloud_run_v2_service.iap_test_service.project
  location = google_cloud_run_v2_service.iap_test_service.location
  name     = google_cloud_run_v2_service.iap_test_service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-iap.iam.gserviceaccount.com"
}
