variable "project_id" {
  type        = string
  description = "The GCP project ID."
}

variable "region" {
  description = "The GCP region for deployment."
  type        = string
  default     = "us-central1"
}

variable "test_user_email" {
  description = "The email address of the user who can invoke the Cloud Run service"
  type        = string
}
