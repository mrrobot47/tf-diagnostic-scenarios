output "connector_id" {
  value       = google_vpc_access_connector.serverless_vpc_connector.id
  description = "The fully qualified ID of the created VPC Connector."
}
