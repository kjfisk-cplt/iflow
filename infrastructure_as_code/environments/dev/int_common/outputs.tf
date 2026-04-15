# ── Resource Group ────────────────────────────────────────────────────────────

output "resource_group_id" {
  description = "Resource ID of the common resource group."
  value       = azurerm_resource_group.common.id
}

output "resource_group_name" {
  description = "Name of the common resource group."
  value       = azurerm_resource_group.common.name
}

# ── User Assigned Managed Identity ───────────────────────────────────────────

output "uai_id" {
  description = "Resource ID of the User Assigned Managed Identity."
  value       = module.uai.resource_id
}

output "uai_name" {
  description = "Name of the User Assigned Managed Identity."
  value       = module.uai.resource.name
}

output "uai_principal_id" {
  description = "Object (principal) ID of the User Assigned Managed Identity. Used for RBAC assignments in downstream stacks."
  value       = module.uai.principal_id
}

output "uai_client_id" {
  description = "Client ID (application ID) of the User Assigned Managed Identity. Used in app configuration."
  value       = module.uai.client_id
}

# ── App Service Plans ─────────────────────────────────────────────────────────

output "asp_logic_id" {
  description = "Resource ID of the Logic Apps Standard App Service Plan."
  value       = module.asp_logic.resource_id
}

output "asp_logic_name" {
  description = "Name of the Logic Apps Standard App Service Plan."
  value       = module.asp_logic.resource.name
}

output "asp_functions_id" {
  description = "Resource ID of the Azure Functions App Service Plan."
  value       = module.asp_functions.resource_id
}

output "asp_functions_name" {
  description = "Name of the Azure Functions App Service Plan."
  value       = module.asp_functions.resource.name
}

output "asp_web_id" {
  description = "Resource ID of the Web Applications App Service Plan."
  value       = module.asp_web.resource_id
}

output "asp_web_name" {
  description = "Name of the Web Applications App Service Plan."
  value       = module.asp_web.resource.name
}
