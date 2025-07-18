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

resource "google_project_service" "cloud_run_api" {
  project = var.project_id
  service = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_storage_bucket" "cloud_run_gcs_bucket" {
  name     = "${var.project_id}-test-sc-1-bucket"
  location = var.region

  public_access_prevention = "enforced"
  uniform_bucket_level_access = true
}

resource "google_service_account" "cloud_run_service_account" {
  account_id   = "test-sc-1-sa"
  display_name = "Test Scenario 1 Service Account"
}

resource "google_storage_bucket_iam_member" "gcs_access" {
  bucket = google_storage_bucket.cloud_run_gcs_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloud_run_service_account.email}"
}

resource "google_cloud_run_v2_service" "cloud_run_hello_service" {
  name     = "test-sc-1-service"
  location = var.region

  template {
    service_account = google_service_account.cloud_run_service_account.email

    volumes {
      name = "gcs-bucket"
      gcs {
        bucket = google_storage_bucket.cloud_run_gcs_bucket.name
        read_only = false
      }
    }

    containers {
      image = "gcr.io/cloudrun/hello"

      volume_mounts {
        name = "gcs-bucket"
        mount_path = "/mnt/bucket"
      }

      env {
        name  = "BUCKET_NAME"
        value = google_storage_bucket.cloud_run_gcs_bucket.name
      }
    }
  }

  depends_on = [
    google_storage_bucket_iam_member.gcs_access,
    google_project_service.cloud_run_api
  ]
}

data "google_iam_policy" "public_access_policy" {
  binding {
    role    = "roles/run.invoker"
    members = ["user:${var.user_email}"]
  }
}

resource "google_cloud_run_v2_service_iam_policy" "cloud_run_public_access" {
  project  = google_cloud_run_v2_service.cloud_run_hello_service.project
  location = google_cloud_run_v2_service.cloud_run_hello_service.location
  name     = google_cloud_run_v2_service.cloud_run_hello_service.name
  policy_data = data.google_iam_policy.public_access_policy.policy_data
}
