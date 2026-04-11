locals {
  tags = module.naming.common_tags

  # Full ARM resource ID of the network resource group.
  # The AVM VNet module requires parent_id (not resource_group_name).
  rg_id = "/subscriptions/${var.subscription_id}/resourceGroups/${module.naming.rg_network}"

  # Subnet resource IDs, keyed by subnet map key, after VNet creation.
  subnet_ids = {
    for k, s in module.vnet.subnets : k => s.resource_id
  }
}
