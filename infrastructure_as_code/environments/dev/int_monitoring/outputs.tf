# ── Resource Group ────────────────────────────────────────────────────────────

output "resource_group_id" {
  description = "Resource ID of the monitoring resource group."
  value       = azurerm_resource_group.monitoring.id
}

output "resource_group_name" {
  description = "Name of the monitoring resource group."
  value       = azurerm_resource_group.monitoring.name
}

# ── Log Analytics Workspaces ──────────────────────────────────────────────────

output "log_analytics_diagnostics_id" {
  description = "Resource ID of the diagnostics Log Analytics workspace."
  value       = module.log_analytics_diagnostics.resource_id
}

output "log_analytics_diagnostics_name" {
  description = "Name of the diagnostics Log Analytics workspace."
  value       = module.log_analytics_diagnostics.resource.name
}

output "log_analytics_diagnostics_workspace_id" {
  description = "Workspace ID (GUID) of the diagnostics Log Analytics workspace."
  value       = module.log_analytics_diagnostics.resource.workspace_id
}

output "log_analytics_tracking_id" {
  description = "Resource ID of the tracking Log Analytics workspace."
  value       = module.log_analytics_tracking.resource_id
}

output "log_analytics_tracking_name" {
  description = "Name of the tracking Log Analytics workspace."
  value       = module.log_analytics_tracking.resource.name
}

output "log_analytics_tracking_workspace_id" {
  description = "Workspace ID (GUID) of the tracking Log Analytics workspace."
  value       = module.log_analytics_tracking.resource.workspace_id
}

# ── Application Insights ──────────────────────────────────────────────────────

output "appi_apim_id" {
  description = "Resource ID of the APIM Application Insights."
  value       = module.appi_apim.resource_id
}

output "appi_apim_instrumentation_key" {
  description = "Instrumentation key for APIM Application Insights."
  value       = module.appi_apim.instrumentation_key
  sensitive   = true
}

output "appi_apim_connection_string" {
  description = "Connection string for APIM Application Insights."
  value       = module.appi_apim.connection_string
  sensitive   = true
}

output "appi_logic_id" {
  description = "Resource ID of the Logic Apps Application Insights."
  value       = module.appi_logic.resource_id
}

output "appi_logic_instrumentation_key" {
  description = "Instrumentation key for Logic Apps Application Insights."
  value       = module.appi_logic.instrumentation_key
  sensitive   = true
}

output "appi_logic_connection_string" {
  description = "Connection string for Logic Apps Application Insights."
  value       = module.appi_logic.connection_string
  sensitive   = true
}

output "appi_functions_id" {
  description = "Resource ID of the Functions Application Insights."
  value       = module.appi_functions.resource_id
}

output "appi_functions_instrumentation_key" {
  description = "Instrumentation key for Functions Application Insights."
  value       = module.appi_functions.instrumentation_key
  sensitive   = true
}

output "appi_functions_connection_string" {
  description = "Connection string for Functions Application Insights."
  value       = module.appi_functions.connection_string
  sensitive   = true
}

# ── Action Group ──────────────────────────────────────────────────────────────

output "action_group_id" {
  description = "Resource ID of the alerts Action Group."
  value       = azurerm_monitor_action_group.alerts.id
}
