# ── Naming Module ─────────────────────────────────────────────────────────────

module "naming" {
  source   = "../_shared/naming"
  workload = var.workload
  env      = var.env
  location = var.location
}

# ── Remote State: Network + Common Stacks ─────────────────────────────────────

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = "int_network.tfstate"
  }
}

data "terraform_remote_state" "common" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = "int_common.tfstate"
  }
}

# ── Resource Group ────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "messaging" {
  name     = module.naming.rg_messaging
  location = var.location
  tags     = local.tags
}

# ── Event Hub Namespace + Event Hub ───────────────────────────────────────────

resource "azurerm_eventhub_namespace" "messaging" {
  name                = module.naming.evh_messaging_name
  location            = var.location
  resource_group_name = azurerm_resource_group.messaging.name
  sku                 = var.eventhub_namespace_sku
  capacity            = var.eventhub_namespace_capacity
  tags                = local.tags

  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  local_authentication_enabled  = true
  auto_inflate_enabled          = false
  maximum_throughput_units      = var.eventhub_namespace_capacity
}

resource "azurerm_eventhub" "workflow_runtime_logs" {
  name              = var.workflow_runtime_logs_eventhub_name
  namespace_id      = azurerm_eventhub_namespace.messaging.id
  partition_count   = var.workflow_runtime_logs_partition_count
  message_retention = var.workflow_runtime_logs_message_retention
}

resource "azurerm_eventhub_consumer_group" "workflowlogs" {
  name                = var.workflow_runtime_logs_consumer_group_name
  namespace_name      = azurerm_eventhub_namespace.messaging.name
  eventhub_name       = azurerm_eventhub.workflow_runtime_logs.name
  resource_group_name = azurerm_resource_group.messaging.name
}

# ── Service Bus Namespaces ────────────────────────────────────────────────────

resource "azurerm_servicebus_namespace" "logging" {
  name                = module.naming.sb_logging_name
  location            = var.location
  resource_group_name = azurerm_resource_group.messaging.name
  sku                 = var.servicebus_sku
  tags                = local.tags

  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  local_auth_enabled            = true
}

resource "azurerm_servicebus_namespace" "messagebroker" {
  name                = module.naming.sb_messagebroker_name
  location            = var.location
  resource_group_name = azurerm_resource_group.messaging.name
  sku                 = var.servicebus_sku
  tags                = local.tags

  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  local_auth_enabled            = true
}

# ── Logging Queues ─────────────────────────────────────────────────────────────

resource "azurerm_servicebus_queue" "logging" {
  for_each = var.logging_queues

  name         = each.key
  namespace_id = azurerm_servicebus_namespace.logging.id

  default_message_ttl                     = each.value.default_message_ttl
  duplicate_detection_history_time_window = each.value.duplicate_detection_history_time_window
  lock_duration                           = each.value.lock_duration
  max_delivery_count                      = each.value.max_delivery_count
  requires_duplicate_detection            = each.value.requires_duplicate_detection
}

# ── Message Broker Topics + Subscriptions ─────────────────────────────────────

resource "azurerm_servicebus_topic" "messagebroker" {
  for_each = var.messagebroker_topics

  name         = each.key
  namespace_id = azurerm_servicebus_namespace.messagebroker.id

  default_message_ttl          = each.value.default_message_ttl
  max_size_in_megabytes        = each.value.max_size_in_megabytes
  requires_duplicate_detection = each.value.requires_duplicate_detection
  support_ordering             = each.value.support_ordering
}

resource "azurerm_servicebus_subscription" "messagebroker" {
  for_each = var.messagebroker_subscriptions

  name     = each.key
  topic_id = azurerm_servicebus_topic.messagebroker[each.value.topic_name].id

  max_delivery_count = each.value.max_delivery_count
  requires_session   = each.value.requires_session
}

resource "azurerm_servicebus_subscription_rule" "messagebroker" {
  for_each = var.messagebroker_subscriptions

  name            = "default"
  subscription_id = azurerm_servicebus_subscription.messagebroker[each.key].id
  filter_type     = "SqlFilter"
  sql_filter      = each.value.sql_filter
}

# ── Private Endpoints ──────────────────────────────────────────────────────────

resource "azurerm_private_endpoint" "messaging" {
  for_each = local.private_endpoints

  name                = "pep-${each.value.name_suffix}-${var.workload}-${var.env}"
  location            = var.location
  resource_group_name = azurerm_resource_group.messaging.name
  subnet_id           = data.terraform_remote_state.network.outputs.subnet_ids[var.pep_subnet_key]
  tags                = local.tags

  private_service_connection {
    name                           = "psc-${each.value.name_suffix}-${var.workload}-${var.env}"
    private_connection_resource_id = each.value.resource_id
    is_manual_connection           = false
    subresource_names              = each.value.subresource_names
  }

  private_dns_zone_group {
    name = "default"
    private_dns_zone_ids = [
      data.terraform_remote_state.network.outputs.private_dns_zone_ids["privatelink.servicebus.windows.net"]
    ]
  }
}

# ── RBAC for Shared UAI ────────────────────────────────────────────────────────

resource "azurerm_role_assignment" "uai_eventhub_data_owner" {
  scope                = azurerm_eventhub_namespace.messaging.id
  role_definition_name = "Azure Event Hubs Data Owner"
  principal_id         = data.terraform_remote_state.common.outputs.uai_principal_id
}

resource "azurerm_role_assignment" "uai_logging_servicebus_data_owner" {
  scope                = azurerm_servicebus_namespace.logging.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = data.terraform_remote_state.common.outputs.uai_principal_id
}

resource "azurerm_role_assignment" "uai_messagebroker_servicebus_data_owner" {
  scope                = azurerm_servicebus_namespace.messagebroker.id
  role_definition_name = "Azure Service Bus Data Owner"
  principal_id         = data.terraform_remote_state.common.outputs.uai_principal_id
}
