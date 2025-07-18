variable "project_id" {
  type        = string
  description = "The GCP project ID."
}

variable "region" {
  type        = string
  description = "The GCP region for resources."
}

variable "zone" {
  type        = string
  description = "The GCP zone for the GCE instance."
}

variable "domain_name" {
  type        = string
  description = "A domain name for the SSL certificate (e.g., example.com). Note: This is used for testing SSL certificate provisioning. The certificate may remain in PROVISIONING state if you don't own the domain."
}
