locals {
  tags                            = module.naming.common_tags
  servicebus_private_dns_zone_key = "privatelink.servicebus.windows.net"

  private_endpoints = {
    eventhub = {
      connection_name   = "psc-${module.naming.evh_messaging_name}"
      dns_zone_key      = local.servicebus_private_dns_zone_key
      endpoint_name     = "pep-${module.naming.evh_messaging_name}"
      resource_id       = azurerm_eventhub_namespace.messaging.id
      subresource_names = ["namespace"]
    }
  }
}
