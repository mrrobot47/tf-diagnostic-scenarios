# Outputs for Test Scenario 11 - Open WebUI Cloud Run Deployment

output "cloud_run_url" {
  description = "URL of the deployed Cloud Run service"
  value       = google_cloud_run_v2_service.open_webui_service.uri
}

output "cloud_run_service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.open_webui_service.name
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository URL for Docker images"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.open_webui_repo.repository_id}"
}

output "database_connection_name" {
  description = "Cloud SQL database connection name"
  value       = google_sql_database_instance.postgres_db.connection_name
}

output "database_private_ip" {
  description = "Private IP address of the PostgreSQL database"
  value       = google_sql_database_instance.postgres_db.private_ip_address
}

output "redis_host" {
  description = "Redis instance host address"
  value       = google_redis_instance.redis_instance.host
}

output "redis_port" {
  description = "Redis instance port"
  value       = google_redis_instance.redis_instance.port
}

output "storage_bucket_name" {
  description = "Name of the GCS storage bucket"
  value       = google_storage_bucket.storage_bucket.name
}

output "cloud_build_trigger_name" {
  description = "Name of the Cloud Build trigger"
  value       = google_cloudbuild_trigger.open_webui_trigger.name
}

output "deployment_instructions" {
  description = "Instructions for accessing and managing the deployment"
  value = <<-EOT
📋 Deployment Complete!

🌐 Cloud Run Service:
   URL: ${google_cloud_run_v2_service.open_webui_service.uri}
   
🔐 Authentication:
   - Service requires authentication
   - Access granted to: ${var.test_user_email}
   
🏗️ Build & Deploy:
   - Cloud Build Trigger: ${google_cloudbuild_trigger.open_webui_trigger.name}
   - Connected Repository: ${var.github_repo_owner}/${var.github_repo_name}
   - Trigger Branch: ${var.github_branch}
   
💾 Resources:
   - Database: ${google_sql_database_instance.postgres_db.name} (PostgreSQL 14)
   - Redis: ${google_redis_instance.redis_instance.name}
   - Storage: ${google_storage_bucket.storage_bucket.name}
   - Images: ${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.open_webui_repo.repository_id}

⚙️ Configuration:
   - Min/Max Instances: 1/1
   - Memory: 4GB
   - CPU: 2000m (2 vCPU)
   - Startup Time: Up to 19 minutes allowed

🚀 Next Steps:
   1. Access the application: ${google_cloud_run_v2_service.open_webui_service.uri}
   2. Push code changes to trigger automatic builds
   3. Monitor logs: gcloud logs read --project=${var.project_id} --resource=cloud_run_revision
   4. Scale if needed: Update min/max instances in Terraform

📊 Monitoring:
   - Cloud Run Metrics: https://console.cloud.google.com/run/detail/${var.region}/${google_cloud_run_v2_service.open_webui_service.name}
   - Build History: https://console.cloud.google.com/cloud-build/builds
   - Logs: https://console.cloud.google.com/logs
  EOT
}

output "useful_commands" {
  description = "Useful gcloud commands for managing the deployment"
  value = <<-EOT
# View service details
gcloud run services describe ${google_cloud_run_v2_service.open_webui_service.name} --region=${var.region}

# View service logs
gcloud logs read --resource=cloud_run_revision --filter="resource.labels.service_name=${google_cloud_run_v2_service.open_webui_service.name}"

# Trigger manual build
gcloud builds triggers run ${google_cloudbuild_trigger.open_webui_trigger.name} --branch=${var.github_branch}

# View recent builds
gcloud builds list --filter="trigger_id=${google_cloudbuild_trigger.open_webui_trigger.id}" --limit=10

# Access Cloud Run service (if you have permissions)
curl -H "Authorization: Bearer $(gcloud auth print-access-token)" ${google_cloud_run_v2_service.open_webui_service.uri}

# View database connection details
gcloud sql instances describe ${google_sql_database_instance.postgres_db.name}

# Connect to database (from authorized network)
gcloud sql connect ${google_sql_database_instance.postgres_db.name} --user=webui --database=openwebui
  EOT
}
