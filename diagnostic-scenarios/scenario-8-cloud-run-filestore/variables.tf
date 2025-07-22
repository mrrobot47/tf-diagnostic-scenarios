variable "project_id" {
  type        = string
  description = "The GCP project ID."
}

variable "region" {
  type        = string
  description = "The GCP region for deployment (e.g., us-central1)."
}

variable "zone" {
  type        = string
  description = "The GCP zone for the Filestore instance (e.g., us-central1-a)."
}
