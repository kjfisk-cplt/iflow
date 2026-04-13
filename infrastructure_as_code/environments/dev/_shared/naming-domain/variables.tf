variable "workload" {
  description = "Platform workload name (e.g. 'iflow'). Must be lowercase alphanumeric with optional hyphens, 2-20 chars."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,18}[a-z0-9]$", var.workload))
    error_message = "workload must be 2-20 lowercase alphanumeric characters or hyphens, starting and ending with alphanumeric."
  }
}

variable "env" {
  description = "Deployment environment. Allowed values: dev, test, prod."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.env)
    error_message = "env must be one of: dev, test, prod."
  }
}

variable "domain" {
  description = "Business domain identifier (e.g. 'hr', 'finance', 'sap', 'crm'). Used to isolate domain-specific integrations."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{1,14}$", var.domain))
    error_message = "domain must be 2-15 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "location" {
  description = "Azure region for resources (e.g. 'swedencentral')."
  type        = string
  default     = "swedencentral"
}