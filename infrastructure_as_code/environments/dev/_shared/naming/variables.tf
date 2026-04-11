variable "workload" {
  description = "Workload / customer abbreviation used in all resource names (e.g. \"iflow\", \"vw\"). Must be lowercase alphanumeric with optional hyphens, 2-20 chars."
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

variable "location" {
  description = "Azure region for resources (e.g. \"swedencentral\")."
  type        = string
  default     = "swedencentral"
}
