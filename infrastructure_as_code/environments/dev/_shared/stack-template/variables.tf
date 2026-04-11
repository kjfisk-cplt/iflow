# Copy this file to your stack directory as variables.tf and extend with
# stack-specific variables below the "Stack-specific" section.

variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
  sensitive   = true
}

variable "workload" {
  description = "Workload abbreviation used in all resource names (e.g. \"iflow\")."
  type        = string
}

variable "env" {
  description = "Deployment environment: dev, test, or prod."
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.env)
    error_message = "env must be one of: dev, test, prod."
  }
}

variable "location" {
  description = "Azure region for all resources in this stack."
  type        = string
  default     = "swedencentral"
}

# ── Terraform State Backend ───────────────────────────────────────────────────
# These variables are used by data.terraform_remote_state blocks to read
# outputs from upstream stacks.

variable "tfstate_resource_group_name" {
  description = "Resource group that contains the Terraform state storage account."
  type        = string
}

variable "tfstate_storage_account_name" {
  description = "Storage account name for Terraform remote state."
  type        = string
}

variable "tfstate_container_name" {
  description = "Blob container name for Terraform state files."
  type        = string
  default     = "tfstate"
}

# ── Stack-specific variables ──────────────────────────────────────────────────
# Add variables unique to this stack below this line.
