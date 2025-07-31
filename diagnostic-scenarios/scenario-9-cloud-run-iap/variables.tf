variable "project_id" {
  type        = string
  description = "The GCP project ID."
}

variable "region" {
  type        = string
  description = "The GCP region for the Cloud Run service."
}

variable "test_user_email" {
  type        = string
  description = "The Google account email (e.g., yourname@example.com) to grant IAP access to."
}

variable "create_oauth_client" {
  type        = bool
  description = "If true, Terraform will create a new IAP Brand and OAuth Client. If false, it will use the existing client credentials provided."
  default     = true
}

variable "existing_oauth_client_id" {
  type        = string
  description = "The OAuth Client ID to use when create_oauth_client is false."
  default     = null
}

variable "existing_oauth_client_secret" {
  type        = string
  description = "The OAuth Client Secret to use when create_oauth_client is false."
  default     = null
  sensitive   = true
}
