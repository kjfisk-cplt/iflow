output "resource_group_id" {
  description = "Resource ID of the network resource group."
  value       = azurerm_resource_group.network.id
}

output "resource_group_name" {
  description = "Name of the network resource group."
  value       = azurerm_resource_group.network.name
}

output "vnet_id" {
  description = "Resource ID of the virtual network."
  value       = module.vnet.resource_id
}

output "vnet_name" {
  description = "Name of the virtual network."
  value       = module.vnet.name
}

output "subnet_ids" {
  description = "Map of subnet resource IDs keyed by subnet map key."
  value       = local.subnet_ids
}

output "nsg_id" {
  description = "Resource ID of the network security group."
  value       = module.nsg.resource_id
}

output "private_dns_zone_ids" {
  description = "Map of private DNS zone resource IDs keyed by zone name."
  value       = { for k, z in azurerm_private_dns_zone.zones : k => z.id }
}

output "pls_monitoring_id" {
  description = "Resource ID of the Azure Monitor Private Link Scope."
  value       = azurerm_monitor_private_link_scope.monitoring.id
}
