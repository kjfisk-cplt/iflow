# ─── Resource Groups ──────────────────────────────────────────────────────────

output "rg_network" {
  description = "Resource group name for networking (VNet, NSG, Private DNS Zones)."
  value       = "rg-${var.workload}-network-${var.env}"
}

output "rg_keyvault" {
  description = "Resource group name for Key Vault."
  value       = "rg-${var.workload}-keyvault-${var.env}"
}

output "rg_storage" {
  description = "Resource group name for storage accounts."
  value       = "rg-${var.workload}-storage-${var.env}"
}

output "rg_messaging" {
  description = "Resource group name for messaging (Event Hub & Service Bus)."
  value       = "rg-${var.workload}-messaging-${var.env}"
}

output "rg_authconnectors" {
  description = "Resource group name for auth connectors (Logic App API connections)."
  value       = "rg-${var.workload}-authconnectors-${var.env}"
}

output "rg_common" {
  description = "Resource group name for common shared resources (App Service Plans, Managed Identity)."
  value       = "rg-${var.workload}-common-${var.env}"
}

output "rg_common_logic" {
  description = "Resource group name for common Logic App Standard."
  value       = "rg-${var.workload}-common-logic-${var.env}"
}

output "rg_database" {
  description = "Resource group name for database resources."
  value       = "rg-${var.workload}-database-${var.env}"
}

output "rg_apim" {
  description = "Resource group name for API Management."
  value       = "rg-${var.workload}-apim-${var.env}"
}

output "rg_appevent_logic" {
  description = "Resource group name for AppEvent Logic App Standard."
  value       = "rg-${var.workload}-appevent-logic-${var.env}"
}

output "rg_ai" {
  description = "Resource group name for AI resources (AI Search, AI Foundry)."
  value       = "rg-${var.workload}-ai-${var.env}"
}

output "rg_monitoring" {
  description = "Resource group name for monitoring resources."
  value       = "rg-${var.workload}-monitoring-${var.env}"
}

output "rg_common_functions" {
  description = "Resource group name for common Azure Functions."
  value       = "rg-${var.workload}-common-functions-${var.env}"
}

output "rg_vw" {
  description = "Resource group name for VW-specific workload."
  value       = "rg-${var.workload}-vw-${var.env}"
}

output "rg_demo_hr" {
  description = "Resource group name for HR demo workload."
  value       = "rg-${var.workload}-demo-hr-${var.env}"
}

output "rg_demo_logic" {
  description = "Resource group name for demo Logic Apps."
  value       = "rg-${var.workload}-demo-logic-${var.env}"
}

# ─── Networking ───────────────────────────────────────────────────────────────

output "vnet_name" {
  description = "Virtual network name."
  value       = "vnet-${var.workload}-integration-${var.env}"
}

output "nsg_name" {
  description = "Network security group name."
  value       = "nsg-${var.workload}-integration-${var.env}"
}

output "pls_monitoring_name" {
  description = "Azure Monitor Private Link Scope name."
  value       = "pls-${var.workload}-monitoring-${var.env}"
}

output "pep_monitoring_name" {
  description = "Private endpoint name for Azure Monitor Private Link Scope."
  value       = "pep-${var.workload}-monitoring-${var.env}"
}

# ─── Key Vault ────────────────────────────────────────────────────────────────
# Key Vault names must be globally unique. A 4-character random suffix is appended
# to ensure uniqueness while maintaining readability and consistency.

output "kv_name" {
  description = "Key Vault name with unique suffix for global uniqueness."
  value       = "kv-${var.workload}-${var.env}-${random_string.unique_suffix.result}"
}

output "pep_kv_name" {
  description = "Private endpoint name for Key Vault."
  value       = "pep-kv-${var.workload}-${var.env}"
}

# ─── Storage Accounts (max 24 chars, lowercase alphanumeric only) ─────────────

output "sto_monitoring" {
  description = "Storage account name for monitoring."
  value       = substr("stomoni${local.workload_sa}${local.env_sa}", 0, 24)
}

output "sto_logic_maps" {
  description = "Storage account name for Logic App maps."
  value       = substr("stolm${local.workload_sa}${local.env_sa}", 0, 24)
}

output "sto_functions" {
  description = "Storage account name for Azure Functions."
  value       = substr("stofunc${local.workload_sa}${local.env_sa}", 0, 24)
}

output "sto_schemas" {
  description = "Storage account name for schemas."
  value       = substr("stoschemas${local.workload_sa}${local.env_sa}", 0, 24)
}

output "sto_logic_state" {
  description = "Storage account name for Logic App state."
  value       = substr("stologic${local.workload_sa}${local.env_sa}", 0, 24)
}

output "sto_archive" {
  description = "Storage account name for archive."
  value       = substr("stoarchive${local.workload_sa}${local.env_sa}", 0, 24)
}

output "sto_ai" {
  description = "Storage account name for AI workloads."
  value       = substr("stoai${local.workload_sa}${local.env_sa}", 0, 24)
}

output "sto_vw" {
  description = "Storage account name for VW workload (SAGA pattern)."
  value       = substr("stosaga${local.workload_sa}${local.env_sa}", 0, 24)
}

# ─── Messaging ────────────────────────────────────────────────────────────────
# Event Hub and Service Bus namespaces require globally unique names across Azure.
# A 4-character random suffix is appended to ensure uniqueness.

output "evh_messaging_name" {
  description = "Event Hub namespace name with unique suffix for global uniqueness."
  value       = "evh-${var.workload}-messaging-${var.env}-${random_string.unique_suffix.result}"
}

output "sb_logging_name" {
  description = "Service Bus namespace name for logging with unique suffix for global uniqueness."
  value       = "sb-${var.workload}-logging-${var.env}-${random_string.unique_suffix.result}"
}

output "sb_messagebroker_name" {
  description = "Service Bus namespace name for message brokering with unique suffix for global uniqueness."
  value       = "sb-${var.workload}-messagebroker-${var.env}-${random_string.unique_suffix.result}"
}

# ─── App Service Plans ────────────────────────────────────────────────────────

output "asp_functions_name" {
  description = "App Service Plan name for Azure Functions."
  value       = "asp-${var.workload}-common-func-${var.env}"
}

output "asp_logic_name" {
  description = "App Service Plan name for Logic App Standard."
  value       = "asp-${var.workload}-common-la-${var.env}"
}

output "asp_web_name" {
  description = "App Service Plan name for web applications."
  value       = "asp-${var.workload}-common-web-${var.env}"
}

# ─── Managed Identity ─────────────────────────────────────────────────────────

output "identity_name" {
  description = "User-assigned managed identity name."
  value       = "id-${var.workload}-common-${var.env}"
}

# ─── Logic Apps (Standard) ────────────────────────────────────────────────────

output "logic_common_name" {
  description = "Logic App Standard name for common workflows."
  value       = "logic-${var.workload}-common-workflows-${var.env}"
}

output "logic_appevent_name" {
  description = "Logic App Standard name for AppEvent workflows."
  value       = "logic-${var.workload}-appevent-workflows-${var.env}"
}

output "logic_demo_name" {
  description = "Logic App Standard name for demo workflows."
  value       = "logic-demo-workflows-${var.env}"
}

output "logic_vw_name" {
  description = "Logic App Standard name for VW workflows."
  value       = "logic-vw-workflows-${var.env}"
}

# ─── Azure Functions ──────────────────────────────────────────────────────────

output "func_common_name" {
  description = "Function App name for common functions."
  value       = "func-${var.workload}-common-${var.env}"
}

output "func_logger_name" {
  description = "Function App name for logger functions."
  value       = "func-${var.workload}-logger-${var.env}"
}

output "func_tracking_name" {
  description = "Function App name for tracking functions."
  value       = "func-${var.workload}-tracking-${var.env}"
}

output "func_vw_claims_name" {
  description = "Function App name for VW claims functions."
  value       = "func-vw-claims-${var.env}"
}

# ─── Web Apps ─────────────────────────────────────────────────────────────────

output "api_demo_hr_name" {
  description = "Web App (API backend) name for HR demo."
  value       = "api-${var.workload}-demo-hr-${var.env}"
}

output "app_demo_hr_name" {
  description = "Web App (frontend) name for HR demo."
  value       = "app-${var.workload}-demo-hr-${var.env}"
}

# ─── Database ─────────────────────────────────────────────────────────────────

output "sql_server_name" {
  description = "Azure SQL Server name."
  value       = "sqlsrv-${var.workload}-${var.env}"
}

output "pep_sql_name" {
  description = "Private endpoint name for SQL Server."
  value       = "pep-sqlsrv-${var.workload}-${var.env}"
}

# ─── API Management ───────────────────────────────────────────────────────────

output "apim_name" {
  description = "API Management instance name."
  value       = "apim-${var.workload}-${var.env}"
}

# ─── AI ───────────────────────────────────────────────────────────────────────

output "search_name" {
  description = "Azure AI Search service name."
  value       = "srch-${var.workload}-${var.env}"
}

output "ai_hub_name" {
  description = "Azure AI Foundry (Cognitive Services) hub name."
  value       = "aif-${var.workload}-${var.env}"
}

# ─── Monitoring ───────────────────────────────────────────────────────────────

output "appi_apim_name" {
  description = "Application Insights name for APIM."
  value       = "appi-${var.workload}-apim-${var.env}"
}

output "appi_logic_name" {
  description = "Application Insights name for Logic Apps."
  value       = "appi-${var.workload}-logic-${var.env}"
}

output "appi_functions_name" {
  description = "Application Insights name for Azure Functions."
  value       = "appi-${var.workload}-functions-${var.env}"
}

output "log_monitoring_name" {
  description = "Log Analytics workspace name for monitoring."
  value       = "log-${var.workload}-monitoring-${var.env}"
}

output "log_tracking_name" {
  description = "Log Analytics workspace name for tracking."
  value       = "log-${var.workload}-tracking-${var.env}"
}

# ─── Common Tags ──────────────────────────────────────────────────────────────

output "common_tags" {
  description = "Common tags applied to all resources in this workload."
  value = {
    Environment = var.env
    Workload    = var.workload
    ManagedBy   = "Terraform"
    Location    = var.location
  }
}
