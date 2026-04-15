# ── Resource Group ────────────────────────────────────────────────────────────

output "resource_group_id" {
  description = "Resource ID of the messaging resource group."
  value       = azurerm_resource_group.messaging.id
}

output "resource_group_name" {
  description = "Name of the messaging resource group."
  value       = azurerm_resource_group.messaging.name
}

# ── Event Hub ─────────────────────────────────────────────────────────────────

output "eventhub_namespace_id" {
  description = "Resource ID of the Event Hub namespace."
  value       = azurerm_eventhub_namespace.messaging.id
}

output "eventhub_namespace_name" {
  description = "Name of the Event Hub namespace."
  value       = azurerm_eventhub_namespace.messaging.name
}

output "workflow_runtime_logs_eventhub_id" {
  description = "Resource ID of the workflow runtime logs Event Hub."
  value       = azurerm_eventhub.workflow_runtime_logs.id
}

output "workflow_runtime_logs_eventhub_name" {
  description = "Name of the workflow runtime logs Event Hub."
  value       = azurerm_eventhub.workflow_runtime_logs.name
}

output "workflow_runtime_logs_consumer_group_id" {
  description = "Resource ID of the workflow runtime logs consumer group."
  value       = azurerm_eventhub_consumer_group.workflow_runtime_logs.id
}

# ── Service Bus ────────────────────────────────────────────────────────────────

output "servicebus_logging_namespace_id" {
  description = "Resource ID of the logging Service Bus namespace."
  value       = azurerm_servicebus_namespace.logging.id
}

output "servicebus_logging_namespace_name" {
  description = "Name of the logging Service Bus namespace."
  value       = azurerm_servicebus_namespace.logging.name
}

output "servicebus_messagebroker_namespace_id" {
  description = "Resource ID of the message broker Service Bus namespace."
  value       = azurerm_servicebus_namespace.messagebroker.id
}

output "servicebus_messagebroker_namespace_name" {
  description = "Name of the message broker Service Bus namespace."
  value       = azurerm_servicebus_namespace.messagebroker.name
}

output "logging_queue_ids" {
  description = "Map of logging Service Bus queue IDs keyed by queue name."
  value       = { for name, queue in azurerm_servicebus_queue.logging : name => queue.id }
}

output "messagebroker_topic_ids" {
  description = "Map of message broker Service Bus topic IDs keyed by topic name."
  value       = { for name, topic in azurerm_servicebus_topic.messagebroker : name => topic.id }
}

output "messagebroker_subscription_ids" {
  description = "Map of message broker Service Bus subscription IDs keyed by subscription name."
  value       = { for name, subscription in azurerm_servicebus_subscription.messagebroker : name => subscription.id }
}

# ── Private Endpoints ─────────────────────────────────────────────────────────

output "private_endpoint_ids" {
  description = "Map of private endpoint IDs keyed by endpoint purpose."
  value       = { for name, pe in azurerm_private_endpoint.messaging : name => pe.id }
}
