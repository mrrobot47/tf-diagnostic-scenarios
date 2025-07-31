output "cloud_run_service_url" {
  value       = google_cloud_run_v2_service.test_sc_9_service.uri
  description = "The IAP-protected URL. Visit this URL to test the login flow."
}

output "created_oauth_client_id" {
  value       = var.create_oauth_client ? one(google_iap_client.test_sc_9_client).client_id : "Not created by this deployment. Using existing client."
  description = "The IAP OAuth Client ID that was created by Terraform."
}
