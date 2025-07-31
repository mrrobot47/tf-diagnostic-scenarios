variable "project_id" {
  type        = string
  description = "The GCP project ID."
}

variable "region" {
  type        = string
  description = "The GCP region for the Cloud Run service."
}

# NEW: Replaces the old test_user_email
variable "iap_members" {
  type        = list(string)
  description = "List of members to grant IAP access. Formats: 'user:email@example.com', 'group:team@example.com'."
  
  validation {
    condition = alltrue([
      for member in var.iap_members : can(regex("^(user|group|serviceAccount|domain):", member))
    ])
    error_message = "All members in iap_members must start with a valid prefix (e.g., 'user:', 'group:')."
  }
}

# NEW: Dedicated variable for the OAuth support email
variable "oauth_support_email" {
  type        = string
  description = "The email address to be displayed on the OAuth consent screen."

  validation {
    condition     = can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.oauth_support_email))
    error_message = "The provided email is not a valid email address format."
  }
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
