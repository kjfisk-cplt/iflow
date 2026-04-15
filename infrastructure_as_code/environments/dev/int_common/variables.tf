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

# ── App Service Plan Configuration ───────────────────────────────────────────

variable "asp_logic_sku" {
  description = "SKU name for the Logic Apps Standard App Service Plan. Use EP1/EP2/EP3 for Elastic Premium."
  type        = string
  default     = "EP1"
}

variable "asp_functions_sku" {
  description = "SKU name for the Azure Functions App Service Plan. Use EP1/EP2/EP3 for Elastic Premium."
  type        = string
  default     = "EP1"
}

variable "asp_web_sku" {
  description = "SKU name for the Web Applications App Service Plan. Use S1/S2/S3 for Standard or P1v3/P2v3 for Premium v3."
  type        = string
  default     = "S1"
}

# ── RBAC Configuration ────────────────────────────────────────────────────────

variable "uai_subscription_role" {
  description = "Azure built-in role name to assign to the User Assigned Managed Identity at subscription scope."
  type        = string
  default     = "Contributor"
}

variable "enable_uai_subscription_role_assignment" {
  description = "Set to true to assign the UAI the subscription-scope role defined in uai_subscription_role. Requires sufficient permissions on the executing principal."
  type        = bool
  default     = false
}
