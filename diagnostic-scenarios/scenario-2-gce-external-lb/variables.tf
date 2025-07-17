variable "project_id" {
  type        = string
  description = "The GCP project ID."
}

variable "zone" {
  type        = string
  description = "The GCP zone for the GCE instance."
}

variable "domain_name" {
  type        = string
  description = "A domain name for the SSL certificate."
}
