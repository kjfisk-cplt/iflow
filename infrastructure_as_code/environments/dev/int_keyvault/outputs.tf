# ── Resource Group ────────────────────────────────────────────────────────────

output "resource_group_id" {
  description = "Resource ID of the Key Vault resource group."
  value       = azurerm_resource_group.keyvault.id
}

output "resource_group_name" {
  description = "Name of the Key Vault resource group."
  value       = azurerm_resource_group.keyvault.name
}

# ── Key Vault ─────────────────────────────────────────────────────────────────

output "keyvault_id" {
  description = "Resource ID of the Key Vault. Used by downstream stacks to assign data-plane RBAC roles."
  value       = module.keyvault.resource_id
}

output "keyvault_name" {
  description = "Name of the Key Vault."
  value       = module.keyvault.name
}

output "keyvault_uri" {
  description = "Vault URI of the Key Vault (e.g. https://<name>.vault.azure.net/). Used for secret references in app configuration."
  value       = module.keyvault.uri
}
