output "verification_command" {
  description = "Run this command to check the logs of the Cloud Run service for a success or failure message."
  value       = "gcloud logging read \"resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"test-sc-8-filestore-mount\" AND severity>=DEFAULT\" --project=${var.project_id} --limit=10 --format='value(textPayload)'"
}

output "authenticated_curl_command" {
  description = "Command to test the service with an authenticated user."
  value       = "echo 'Visit this URL in your browser:'; echo 'curl -H \"Authorization: Bearer $(gcloud auth print-identity-token)\" ${google_cloud_run_v2_service.cloudrun_filestore_connectivity_tester.uri}'"
}

output "cloudrun_filestore_connectivity_tester_url" {
    description = "The URL of the Cloud Run service."
    value = google_cloud_run_v2_service.cloudrun_filestore_connectivity_tester.uri
}
