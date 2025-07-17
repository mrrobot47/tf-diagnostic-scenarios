output "vm_name" {
  value       = google_compute_instance.test_vm.name
  description = "The name of the private VM. Check its serial port logs to verify success."
}

output "verification_command" {
  value = "gcloud compute instances get-serial-port-output ${google_compute_instance.test_vm.name} --zone=${var.zone} --project=${var.project_id}"
}
