# ─── Resource Group ───────────────────────────────────────────────────────────

output "rg_name" {
  description = "Resource group name for this domain."
  value       = "rg-${local.base_prefix}-${var.env}"
}

# ─── Logic Apps (Standard) ────────────────────────────────────────────────────

output "logic_app_name" {
  description = "Logic App Standard name for domain workflows."
  value       = "logic-${local.base_prefix}-${var.env}"
}

output "logic_app_name_fn" {
  description = "Name generator for specific Logic App integrations. Use: \"{prefix}-{purpose}-{suffix}\"."
  value = {
    prefix  = "logic-${local.base_prefix}"
    suffix  = var.env
    pattern = "logic-${local.base_prefix}-{PURPOSE}-${var.env}"
  }
}

# ─── Azure Functions ──────────────────────────────────────────────────────────

output "func_app_name" {
  description = "Function App name for domain."
  value       = "func-${local.base_prefix}-${var.env}"
}

output "func_app_name_fn" {
  description = "Name generator for specific Function Apps. Use: \"{prefix}-{purpose}-{suffix}\"."
  value = {
    prefix  = "func-${local.base_prefix}"
    suffix  = var.env
    pattern = "func-${local.base_prefix}-{PURPOSE}-${var.env}"
  }
}

# ─── Storage Account (max 24 chars) ───────────────────────────────────────────

output "storage_account_name" {
  description = "Storage account name for domain (max 24 chars, no hyphens)."
  value       = substr("sto${local.domain_sa}${local.workload_sa}${local.env_sa}", 0, 24)
}

output "storage_account_name_fn" {
  description = "Name generator for specific storage accounts. Use: substr(\"{prefix}{purpose}{suffix}\", 0, 24)."
  value = {
    prefix  = "sto${local.domain_sa}"
    suffix  = "${local.workload_sa}${local.env_sa}"
    pattern = "sto${local.domain_sa}{PURPOSE}${local.workload_sa}${local.env_sa}"
  }
}

# ─── Key Vault ────────────────────────────────────────────────────────────────

output "keyvault_name" {
  description = "Key Vault name for domain secrets."
  value       = "kv-${local.base_prefix}-${var.env}"
}

# ─── Service Bus ──────────────────────────────────────────────────────────────

output "servicebus_namespace_name" {
  description = "Service Bus namespace name for domain messaging."
  value       = "sb-${local.base_prefix}-${var.env}"
}

# ─── Event Hub ────────────────────────────────────────────────────────────────

output "eventhub_namespace_name" {
  description = "Event Hub namespace name for domain events."
  value       = "evh-${local.base_prefix}-${var.env}"
}

# ─── App Service Plan ─────────────────────────────────────────────────────────

output "asp_logic_name" {
  description = "App Service Plan name for domain Logic Apps."
  value       = "asp-${local.base_prefix}-la-${var.env}"
}

output "asp_func_name" {
  description = "App Service Plan name for domain Functions."
  value       = "asp-${local.base_prefix}-func-${var.env}"
}

# ─── Private Endpoints ────────────────────────────────────────────────────────

output "pep_prefix" {
  description = "Private endpoint prefix for domain resources. Append resource type: \"{pep_prefix}-{resource}-{env}\"."
  value       = "pep-${local.base_prefix}"
}

# ─── Web Apps / APIs ──────────────────────────────────────────────────────────

output "api_name" {
  description = "API App name for domain."
  value       = "api-${local.base_prefix}-${var.env}"
}

output "app_name" {
  description = "Web App name for domain."
  value       = "app-${local.base_prefix}-${var.env}"
}

# ─── Managed Identity ─────────────────────────────────────────────────────────

output "identity_name" {
  description = "User-assigned managed identity name for domain."
  value       = "id-${local.base_prefix}-${var.env}"
}

# ─── Tags ─────────────────────────────────────────────────────────────────────

output "tags" {
  description = "Standard tags for all domain resources. Merge with resource-specific tags."
  value = {
    workload    = var.workload
    environment = var.env
    domain      = var.domain
    managed_by  = "terraform"
  }
}

# ─── Computed Values ──────────────────────────────────────────────────────────

output "base_prefix" {
  description = "Base prefix for custom naming: {workload}-{domain}."
  value       = local.base_prefix
}