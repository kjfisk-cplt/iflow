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

# ── Monitoring Configuration ──────────────────────────────────────────────────

variable "log_analytics_sku" {
  description = "SKU for Log Analytics workspaces. Possible values: Free, PerNode, Premium, Standard, Standalone, Unlimited, CapacityReservation, PerGB2018."
  type        = string
  default     = "PerGB2018"
}

variable "log_analytics_retention_in_days" {
  description = "Retention period for Log Analytics workspaces (30-730 days, or 7 for Free tier)."
  type        = number
  default     = 30
}

variable "action_group_email_receivers" {
  description = "List of email receivers for the Action Group."
  type = list(object({
    name                    = string
    email_address           = string
    use_common_alert_schema = optional(bool, true)
  }))
  default = []
}
