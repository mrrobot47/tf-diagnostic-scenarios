output "service_url" {
  description = "URL to access the Cloud Run service and see the SQL connection test results"
  value       = google_cloud_run_v2_service.test_service.uri
}

output "authenticated_curl_command" {
  description = "Run this command to access the service with authentication"
  value       = "curl -H \"Authorization: Bearer $(gcloud auth print-identity-token)\" ${google_cloud_run_v2_service.test_service.uri}"
}
