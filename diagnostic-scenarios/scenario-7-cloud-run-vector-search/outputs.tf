output "cloud_run_service_url" {
  value       = google_cloud_run_v2_service.test_service.uri
  description = "URL of the deployed test service. Use the authenticated_curl_command to test."
}

output "verification_command_logs" {
  description = "Run this command to check the container logs for a success or failure message."
  value       = "gcloud logging read \"resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"test-sc-7-vector-search-connect\" AND severity>=DEFAULT\" --project=${var.project_id} --limit=20 --format='value(textPayload)'"
}

output "authenticated_curl_command" {
  description = "Run this command to test the service endpoint with an authenticated request."
  value       = "curl -H \"Authorization: Bearer $(gcloud auth print-identity-token)\" ${google_cloud_run_v2_service.test_service.uri}"
}