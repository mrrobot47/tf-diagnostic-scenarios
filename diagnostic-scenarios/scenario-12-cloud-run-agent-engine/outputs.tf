output "cloud_run_service_url" {
  value       = google_cloud_run_v2_service.reasoning_engine_tester.uri
  description = "Visit this URL to see the reasoning engine test results and verify connectivity."
}

output "service_account_email" {
  value       = google_service_account.reasoning_engine_sa.email
  description = "The service account email used by the Cloud Run service for Vertex AI authentication."
}

output "project_id" {
  value       = var.project_id
  description = "The GCP project ID where resources were deployed."
}

output "region" {
  value       = var.region
  description = "The GCP region where resources were deployed."
}

output "test_instructions" {
  value = <<-EOT
    1. Visit the Cloud Run service URL above to see test results
    2. The service will automatically:
       - List all available reasoning engines in your project
       - Test API connectivity with a sample query
       - Display formatted results in a web interface
    3. Check the test results to verify:
       - Reasoning engines are accessible
       - API authentication is working
       - Network connectivity is established
  EOT
  description = "Instructions for using the deployed test service."
}
