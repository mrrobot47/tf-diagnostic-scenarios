output "load_balancer_ip" {
  value       = google_compute_global_address.load_balancer_static_ip.address
  description = "The external IP address of the load balancer."
}
