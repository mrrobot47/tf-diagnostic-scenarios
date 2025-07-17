variable "project_id" {
  type        = string
  description = "The GCP project ID."
}

variable "region" {
  type        = string
  description = "The GCP region for deployment."
}

variable "zone" {
  type        = string
  description = "The GCP zone for the GCE instance."
}
