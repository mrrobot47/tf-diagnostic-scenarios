output "cloud_run_service_url" {
  value       = google_cloud_run_v2_service.main_service.uri
  description = "Visit this URL to verify the service is running and see test results."
}
