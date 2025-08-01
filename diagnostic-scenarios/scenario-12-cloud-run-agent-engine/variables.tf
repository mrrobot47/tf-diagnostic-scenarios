variable "project_id" {
  type        = string
  description = "The GCP project ID where resources will be created."

  validation {
    condition     = length(var.project_id) > 0
    error_message = "Project ID cannot be empty."
  }
}

variable "region" {
  description = "The GCP region for deployment."
  type        = string
  default     = "us-central1"

  validation {
    condition = contains([
      "us-central1", "us-east1", "us-east4", "us-west1", "us-west2", "us-west3", "us-west4",
      "europe-west1", "europe-west2", "europe-west3", "europe-west4", "europe-west6",
      "asia-east1", "asia-northeast1", "asia-south1", "asia-southeast1"
    ], var.region)
    error_message = "Region must be a valid GCP region that supports Vertex AI."
  }
}

variable "test_user_email" {
  description = "The email address of the user who can invoke the Cloud Run service to see test results."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.test_user_email))
    error_message = "test_user_email must be a valid email address."
  }
}

variable "use_default_network" {
  description = "Whether to use the default VPC network instead of creating a custom one. Set to true for restrictive environments."
  type        = bool
  default     = false
}

variable "enable_apis_automatically" {
  description = "Whether to automatically enable required APIs. Set to false if APIs are managed separately."
  type        = bool
  default     = true
}
