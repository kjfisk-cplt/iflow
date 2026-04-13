# ── Naming Module ─────────────────────────────────────────────────────────────

module "naming" {
  source   = "../_shared/naming"
  workload = var.workload
  env      = var.env
  location = var.location
}

# ── Resource Group ────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "network" {
  name     = module.naming.rg_network
  location = var.location
  tags     = local.tags
}

# ── Network Security Group ────────────────────────────────────────────────────
# AVM: https://github.com/Azure/terraform-azurerm-avm-res-network-networksecuritygroup

module "nsg" {
  source  = "Azure/avm-res-network-networksecuritygroup/azurerm"
  version = "~> 0.4"

  name                = module.naming.nsg_name
  resource_group_name = azurerm_resource_group.network.name
  location            = var.location
  tags                = local.tags
  enable_telemetry    = false
}

# ── Virtual Network ───────────────────────────────────────────────────────────
# AVM: https://github.com/Azure/terraform-azurerm-avm-res-network-virtualnetwork
#
# IMPORTANT: This module uses the AzAPI provider internally.
# It requires parent_id (full RG resource ID), NOT resource_group_name.

module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "~> 0.17"

  name          = module.naming.vnet_name
  location      = var.location
  parent_id     = local.rg_id
  address_space = var.vnet_address_space
  tags          = local.tags

  subnets = {
    for k, s in var.subnets : k => {
      name             = k
      address_prefixes = s.address_prefixes

      private_endpoint_network_policies             = s.private_endpoint_network_policies
      private_link_service_network_policies_enabled = s.private_link_service_network_policies_enabled

      # Attach the same NSG to every subnet
      network_security_group = {
        id = module.nsg.resource_id
      }

      service_endpoints_with_location = length(s.service_endpoints) > 0 ? [
        for se in s.service_endpoints : {
          service   = se.service
          locations = se.locations
        }
      ] : null

      delegations = length(s.delegations) > 0 ? [
        for d in s.delegations : {
          name               = d.name
          service_delegation = d.service_delegation
        }
      ] : null
    }
  }

  enable_telemetry = false
}

# ── Private DNS Zones ─────────────────────────────────────────────────────────
# One resource block with for_each creates all zones without repetition.

resource "azurerm_private_dns_zone" "zones" {
  for_each = var.private_dns_zones

  name                = each.key
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.tags
}

# ── Private DNS Zone → VNet Links ─────────────────────────────────────────────

resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each = var.private_dns_zones

  name                  = "link-${module.naming.vnet_name}"
  resource_group_name   = azurerm_resource_group.network.name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.key].name
  virtual_network_id    = module.vnet.resource_id
  registration_enabled  = false
  tags                  = local.tags
}

# ── Azure Monitor Private Link Scope ─────────────────────────────────────────

resource "azurerm_monitor_private_link_scope" "monitoring" {
  name                = module.naming.pls_monitoring_name
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.tags
}

# ── Private Endpoint for Azure Monitor Private Link Scope ─────────────────────

resource "azurerm_private_endpoint" "monitoring" {
  name                = module.naming.pep_monitoring_name
  resource_group_name = azurerm_resource_group.network.name
  location            = var.location
  subnet_id           = local.subnet_ids[var.pep_monitoring_subnet_key]
  tags                = local.tags

  private_service_connection {
    name                           = module.naming.pep_monitoring_name
    private_connection_resource_id = azurerm_monitor_private_link_scope.monitoring.id
    is_manual_connection           = false
    subresource_names              = ["azuremonitor"]
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.zones["privatelink.monitor.azure.com"].id,
      azurerm_private_dns_zone.zones["privatelink.ods.opinsights.azure.com"].id,
      azurerm_private_dns_zone.zones["privatelink.oms.opinsights.azure.com"].id,
      azurerm_private_dns_zone.zones["privatelink.agentsvc.azure-automation.net"].id,
      azurerm_private_dns_zone.zones["privatelink.blob.core.windows.net"].id,
    ]
  }

  depends_on = [module.vnet]
}
