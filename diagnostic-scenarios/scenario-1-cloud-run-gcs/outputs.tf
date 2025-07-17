output "cloud_run_service_url" {
  value       = google_cloud_run_v2_service.hello_world.uri
  description = "URL of the deployed test service."
}
