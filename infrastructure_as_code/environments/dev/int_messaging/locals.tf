locals {
  tags = module.naming.common_tags

  private_endpoints = {
    eventhub = {
      name_suffix       = "eventhub"
      resource_id       = azurerm_eventhub_namespace.messaging.id
      subresource_names = ["namespace"]
    }
    servicebus_logging = {
      name_suffix       = "sblogging"
      resource_id       = azurerm_servicebus_namespace.logging.id
      subresource_names = ["namespace"]
    }
    servicebus_messagebroker = {
      name_suffix       = "sbmsgbroker"
      resource_id       = azurerm_servicebus_namespace.messagebroker.id
      subresource_names = ["namespace"]
    }
  }
}
