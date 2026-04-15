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

# ── Key Vault Configuration ───────────────────────────────────────────────────

variable "kv_sku" {
  description = "SKU name for the Key Vault. Allowed values: standard, premium."
  type        = string
  default     = "standard"
  validation {
    condition     = contains(["standard", "premium"], var.kv_sku)
    error_message = "kv_sku must be one of: standard, premium."
  }
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain deleted Key Vault objects before permanent deletion. Minimum 7, maximum 90."
  type        = number
  default     = 30
  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days must be between 7 and 90."
  }
}

variable "purge_protection_enabled" {
  description = "Enable purge protection on the Key Vault. When true, deleted objects cannot be permanently purged during the retention period. Recommended true for prod."
  type        = bool
  default     = false
}

variable "pep_subnet_key" {
  description = "Key of the subnet (from the network stack's subnets map) to attach the Key Vault private endpoint."
  type        = string
  default     = "snet-private-endpoints"
}

# ── Terraform State Backend ───────────────────────────────────────────────────
# Used by data.terraform_remote_state blocks to read outputs from upstream stacks.

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
