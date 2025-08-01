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

locals {
  common_labels = {
    application = "open-webui"
    scenario    = "test-sc-11"
    managed-by  = "terraform"
  }
}

# 1. Enable all necessary APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com", "storage.googleapis.com", "iam.googleapis.com",
    "sqladmin.googleapis.com", "compute.googleapis.com", "servicenetworking.googleapis.com",
    "redis.googleapis.com", "cloudbuild.googleapis.com", "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com"
  ])
  project            = var.project_id
  service            = each.key
  disable_on_destroy = false
}

# 2. Create the VPC and Subnet
resource "google_compute_network" "vpc" {
  name                    = "test-sc-11-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "subnet" {
  name          = "test-sc-11-subnet"
  ip_cidr_range = "10.11.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# 3. Set up Private Service Access for SQL and Redis
resource "google_compute_global_address" "private_service_access" {
  name          = "test-sc-11-private-access"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "vpc_peering" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_access.name]
  deletion_policy         = "ABANDON"
  depends_on              = [google_compute_subnetwork.subnet]
}

# 4. Add Cloud NAT for outbound internet access
resource "google_compute_router" "router" {
  name    = "test-sc-11-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "test-sc-11-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# 5. Provision the GCS bucket for storage
resource "google_storage_bucket" "storage_bucket" {
  name                        = "test-sc-11-storage-bucket-${var.project_id}"
  location                    = var.region
  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true
  depends_on                  = [google_project_service.apis]

  labels = local.common_labels
}

# 6. Provision the private Cloud SQL (PostgreSQL) instance
resource "google_sql_database_instance" "postgres_db" {
  name                = "test-sc-11-postgres-db"
  region              = var.region
  database_version    = "POSTGRES_14"
  deletion_protection = false
  settings {
    tier = "db-g1-small"
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }
  }
  depends_on = [google_service_networking_connection.vpc_peering]
}

# Create database and user
resource "google_sql_database" "webui_database" {
  name     = "openwebui"
  instance = google_sql_database_instance.postgres_db.name
}

resource "google_sql_user" "webui_user" {
  name        = "webui"
  instance    = google_sql_database_instance.postgres_db.name
  password_wo = "webui123!"
}

# 7. Provision the Redis instance
resource "google_redis_instance" "redis_instance" {
  name               = "test-sc-11-redis-instance"
  region             = var.region
  tier               = "BASIC"
  memory_size_gb     = 1
  authorized_network = google_compute_network.vpc.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"
  depends_on         = [google_service_networking_connection.vpc_peering]

  labels = local.common_labels
}

# 8. Create Artifact Registry repository
resource "google_artifact_registry_repository" "open_webui_repo" {
  location      = var.region
  repository_id = "test-sc-11-open-webui-images"
  description   = "Docker repository for Open WebUI images"
  format        = "DOCKER"

  labels = local.common_labels

  depends_on = [google_project_service.apis]
}

# 9. Create secrets in Secret Manager
resource "google_secret_manager_secret" "database_url" {
  secret_id = "test-sc-11-database-url"
  labels    = local.common_labels

  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "database_url" {
  secret         = google_secret_manager_secret.database_url.id
  secret_data_wo = "postgresql://webui:webui123!@${google_sql_database_instance.postgres_db.private_ip_address}:5432/openwebui"
}

resource "google_secret_manager_secret" "redis_url" {
  secret_id = "test-sc-11-redis-url"
  labels    = local.common_labels

  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "redis_url" {
  secret         = google_secret_manager_secret.redis_url.id
  secret_data_wo = "redis://${google_redis_instance.redis_instance.host}:6379"
}

resource "google_secret_manager_secret" "webui_secret_key" {
  secret_id = "test-sc-11-webui-secret-key"
  labels    = local.common_labels

  replication {
    auto {}
  }
  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "webui_secret_key" {
  secret         = google_secret_manager_secret.webui_secret_key.id
  secret_data_wo = "test-secret-key-change-in-production"
}

# 10. Create Service Accounts
resource "google_service_account" "cloud_run_sa" {
  account_id   = "test-sc-11-cloudrun-sa"
  display_name = "Test Scenario 11 Cloud Run Service Account"
  depends_on   = [google_project_service.apis]
}

resource "google_service_account" "cloud_build_sa" {
  account_id   = "test-sc-11-cloudbuild-sa"
  display_name = "Test Scenario 11 Cloud Build Service Account"
  depends_on   = [google_project_service.apis]
}

# 11. Grant IAM permissions for Cloud Run SA
resource "google_project_iam_member" "cloud_run_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "cloud_run_redis_editor" {
  project = var.project_id
  role    = "roles/redis.editor"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_storage_bucket_iam_member" "cloud_run_gcs_access" {
  bucket = google_storage_bucket.storage_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "cloud_run_database_url_access" {
  secret_id = google_secret_manager_secret.database_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "cloud_run_redis_url_access" {
  secret_id = google_secret_manager_secret.redis_url.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "cloud_run_webui_secret_access" {
  secret_id = google_secret_manager_secret.webui_secret_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# 12. Grant IAM permissions for Cloud Build SA
resource "google_project_iam_member" "cloud_build_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

resource "google_project_iam_member" "cloud_build_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

resource "google_project_iam_member" "cloud_build_artifact_admin" {
  project = var.project_id
  role    = "roles/artifactregistry.admin"
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

resource "google_project_iam_member" "cloud_build_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloud_build_sa.email}"
}

# 13. Reference external cloudbuild-initial.yaml file
# File should exist in project directory

# 14. Initial Cloud Build for base image (runs after trigger is created)
resource "null_resource" "initial_image_build" {
  triggers = {
    # Force rebuild when Artifact Registry repo is recreated
    artifact_registry_id = google_artifact_registry_repository.open_webui_repo.id
    # Force rebuild when trigger changes (but don't create circular dependency)
    trigger_name = "test-sc-11-open-webui-trigger"
    github_branch = var.github_branch
  }

  provisioner "local-exec" {
    command = <<EOT
      # Image that might exist in Artifact Registry
      IMAGE_TAG="${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.open_webui_repo.repository_id}/open-webui:latest"

      echo "Checking if image '$IMAGE_TAG' already exists..."

      # Check if the image can be described. If not, the command fails.
      if gcloud artifacts docker images describe "$IMAGE_TAG" --project=${var.project_id} --quiet 2>/dev/null; then
        echo "✅ Image already exists. Skipping build."
      else
        echo "Image not found. Triggering Cloud Build from connected GitHub repository..."
        
        # Trigger the existing Cloud Build trigger (connected to GitHub repo)
        # This will build from the connected repository, not local files
        TRIGGER_ID=$(gcloud builds triggers list \
          --project=${var.project_id} \
          --filter="name:test-sc-11-open-webui-trigger" \
          --format="value(id)" \
          --limit=1)
        
        if [ -n "$TRIGGER_ID" ]; then
          echo "Found trigger ID: $TRIGGER_ID"
          echo "Running build from connected GitHub repository..."
          
          BUILD_ID=$(gcloud builds triggers run $TRIGGER_ID \
            --project=${var.project_id} \
            --branch=${var.github_branch} \
            --format="value(metadata.build.id)")
          
          if [ -n "$BUILD_ID" ]; then
            echo "Build started with ID: $BUILD_ID"
            echo "Waiting for build to complete..."
            
            # Wait for build to complete (with timeout)
            gcloud builds log $BUILD_ID --stream --project=${var.project_id}
            
            # Check if build was successful
            BUILD_STATUS=$(gcloud builds describe $BUILD_ID \
              --project=${var.project_id} \
              --format="value(status)")
            
            if [ "$BUILD_STATUS" = "SUCCESS" ]; then
              echo "✅ Initial image build completed successfully"
            else
              echo "❌ Initial image build failed with status: $BUILD_STATUS"
              exit 1
            fi
          else
            echo "❌ Failed to start build"
            exit 1
          fi
        else
          echo "❌ Cloud Build trigger not found. Please ensure the trigger is created first."
          echo "Trigger name: test-sc-11-open-webui-trigger"
          exit 1
        fi
      fi
    EOT
  }

  depends_on = [
    google_artifact_registry_repository.open_webui_repo,
    google_project_iam_member.cloud_build_artifact_admin,
    google_service_account.cloud_build_sa,
    # Note: Depends on trigger being created, but not directly referencing it to avoid cycle
    google_project_iam_member.cloud_build_run_admin
  ]
}

# 15. Cloud Build Trigger
resource "google_cloudbuild_trigger" "open_webui_trigger" {
  name        = "test-sc-11-open-webui-trigger"
  description = "Build and deploy Open WebUI on push to branch"

  github {
    owner = var.github_repo_owner
    name  = var.github_repo_name

    push {
      branch = "^${var.github_branch}$"
    }
  }

  service_account = google_service_account.cloud_build_sa.id

  build {
    timeout = "1200s"

    options {
      machine_type = "E2_HIGHCPU_8"
      logging      = "CLOUD_LOGGING_ONLY"
    }

    # Build steps
    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "build",
        "-t", "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.open_webui_repo.repository_id}/open-webui:$SHORT_SHA",
        "-t", "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.open_webui_repo.repository_id}/open-webui:latest",
        "."
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.open_webui_repo.repository_id}/open-webui:$SHORT_SHA"
      ]
    }

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
        "push",
        "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.open_webui_repo.repository_id}/open-webui:latest"
      ]
    }

    # Deploy to Cloud Run
    step {
      name = "gcr.io/cloud-builders/gcloud"
      args = [
        "run", "deploy", "test-sc-11-open-webui",
        "--image", "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.open_webui_repo.repository_id}/open-webui:$SHORT_SHA",
        "--region", var.region,
        "--platform", "managed",
        "--service-account", google_service_account.cloud_run_sa.email,
        "--vpc-connector", "",
        "--vpc-egress", "all-traffic",
        "--memory", "4Gi",
        "--cpu", "2000m",
        "--min-instances", "1",
        "--max-instances", "1",
        "--timeout", "3600",
        "--no-allow-unauthenticated"
      ]
    }
  }

  depends_on = [
    google_service_account.cloud_build_sa,
    google_project_iam_member.cloud_build_run_admin,
    google_artifact_registry_repository.open_webui_repo
  ]
}

# 16. No VPC Connector needed - using direct VPC egress

# 17. Deploy the Cloud Run service
resource "google_cloud_run_v2_service" "open_webui_service" {
  provider = google-beta
  name     = "test-sc-11-open-webui"
  location = var.region

  deletion_protection = false

  labels = local.common_labels

  template {
    service_account = google_service_account.cloud_run_sa.email
    
    labels = local.common_labels

    scaling {
      min_instance_count = 1
      max_instance_count = 1
    }

    vpc_access {
      network_interfaces {
        network    = google_compute_network.vpc.id
        subnetwork = google_compute_subnetwork.subnet.id
        tags       = ["cloud-run-service"]
      }
      egress = "ALL_TRAFFIC"
    }

    # Cloud Storage FUSE volumes
    volumes {
      name = "app-data-storage"
      gcs {
        bucket    = google_storage_bucket.storage_bucket.name
        read_only = false
      }
    }

    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.open_webui_repo.repository_id}/open-webui:latest"
      name  = "open-webui"

      resources {
        limits = {
          cpu    = "2000m"
          memory = "4Gi"
        }
        cpu_idle = true
      }

      ports {
        name           = "http1"
        container_port = 8080
      }

      # Volume mounts
      volume_mounts {
        name       = "app-data-storage"
        mount_path = "/app/backend/data"
      }

      # Environment variables with secrets
      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.database_url.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "REDIS_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.redis_url.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "WEBUI_SECRET_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.webui_secret_key.secret_id
            version = "latest"
          }
        }
      }

      # Storage configuration
      env {
        name  = "STORAGE_PROVIDER"
        value = "s3"
      }

      env {
        name  = "S3_BUCKET_NAME"
        value = google_storage_bucket.storage_bucket.name
      }

      env {
        name  = "S3_ENDPOINT_URL"
        value = "https://storage.googleapis.com"
      }

      env {
        name  = "ENVIRONMENT"
        value = "test-sc-11"
      }

      # Health check probes - optimized for slow startup (15+ minutes)
      startup_probe {
        initial_delay_seconds = 240  # Maximum allowed: 4 minutes
        timeout_seconds       = 30
        period_seconds        = 30   # Check every 30 seconds
        failure_threshold     = 30   # Allow 30 failures = 15 more minutes after initial delay

        http_get {
          path = "/health"  # Use /health endpoint if available, otherwise "/"
          port = 8080
        }
      }

      liveness_probe {
        initial_delay_seconds = 240  # Maximum allowed: 4 minutes  
        timeout_seconds       = 30
        period_seconds        = 60   # Check every minute
        failure_threshold     = 10   # Allow up to 10 minutes of unresponsiveness

        http_get {
          path = "/health"  # Use /health endpoint if available, otherwise "/"
          port = 8080
        }
      }
    }

    timeout = "3600s"
  }

  traffic {
    percent = 100
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }

  depends_on = [
    google_project_iam_member.cloud_run_sql_client,
    google_project_iam_member.cloud_run_redis_editor,
    google_storage_bucket_iam_member.cloud_run_gcs_access,
    google_secret_manager_secret_iam_member.cloud_run_database_url_access,
    google_compute_router_nat.nat,
    null_resource.initial_image_build
  ]
}

# 18. Cloud Run service invoker permission (for testing)
resource "google_cloud_run_v2_service_iam_member" "invoker" {
  project  = google_cloud_run_v2_service.open_webui_service.project
  location = google_cloud_run_v2_service.open_webui_service.location
  name     = google_cloud_run_v2_service.open_webui_service.name
  role     = "roles/run.invoker"
  member   = "user:${var.test_user_email}"
}

