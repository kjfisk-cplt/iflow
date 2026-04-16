variable "subscription_id" {
  description = "Azure subscription ID."
  type        = string
  sensitive   = true
}

variable "workload" {
  description = "Workload abbreviation used in all resource names (e.g. \"iflow\")."
  type        = string
}

variable "env" {
  description = "Deployment environment: dev, test, or prod."
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.env)
    error_message = "env must be one of: dev, test, prod."
  }
}

variable "location" {
  description = "Azure region for all resources in this stack."
  type        = string
  default     = "swedencentral"
}

# ── Messaging Configuration ───────────────────────────────────────────────────

variable "eventhub_namespace_sku" {
  description = "SKU for the Event Hub namespace."
  type        = string
  default     = "Standard"
  validation {
    condition     = var.eventhub_namespace_sku == "Standard"
    error_message = "eventhub_namespace_sku must be Standard for this stack."
  }
}

variable "eventhub_namespace_capacity" {
  description = "Throughput units for the Event Hub namespace."
  type        = number
  default     = 1
}

variable "workflow_runtime_logs_eventhub_name" {
  description = "Event Hub name for Logic App workflow runtime logs."
  type        = string
  default     = "workflowruntimelogs"
}

variable "workflow_runtime_logs_consumer_group_name" {
  description = "Consumer group for processing workflow runtime logs."
  type        = string
  default     = "workflowlogs"
}

variable "workflow_runtime_logs_partition_count" {
  description = "Partition count for the workflow runtime logs Event Hub."
  type        = number
  default     = 2
}

variable "workflow_runtime_logs_message_retention" {
  description = "Retention in days for the workflow runtime logs Event Hub."
  type        = number
  default     = 1
}

variable "servicebus_sku" {
  description = "SKU for Service Bus namespaces."
  type        = string
  default     = "Standard"
  validation {
    condition     = var.servicebus_sku == "Standard"
    error_message = "servicebus_sku must be Standard for this stack."
  }
}

variable "logging_queues" {
  description = "Logging and tracking queues created in the logging Service Bus namespace."
  type = map(object({
    default_message_ttl                     = optional(string, "P14D")
    duplicate_detection_history_time_window = optional(string, "PT10M")
    lock_duration                           = optional(string, "PT1M")
    max_delivery_count                      = optional(number, 10)
    requires_duplicate_detection            = optional(bool, false)
  }))
  default = {
    errortracking          = {}
    filearchivetracking    = {}
    freetexttracking       = {}
    keyvaluetracking       = {}
    messagecontenttracking = {}
    messageflowtracking = {
      duplicate_detection_history_time_window = "PT1H"
      requires_duplicate_detection            = true
    }
  }
}

variable "messagebroker_topics" {
  description = "Topics created in the message broker Service Bus namespace."
  type = map(object({
    default_message_ttl          = optional(string, "P14D")
    max_size_in_megabytes        = optional(number, 1024)
    requires_duplicate_detection = optional(bool, false)
    support_ordering             = optional(bool, false)
  }))
  default = {
    DeferredMessages           = {}
    EventNotification          = {}
    "Demo-Employee"            = {}
    "Demo-Deferred"            = {}
    "Demo-Single-Deferred"     = {}
    "Demo-Session-LongRunning" = {}
    "Demo-Session-Convoy"      = {}
  }
}

variable "messagebroker_subscriptions" {
  description = "Subscriptions and SQL filters for message broker topics."
  type = map(object({
    max_delivery_count = optional(number, 10)
    requires_session   = optional(bool, false)
    sql_filter         = string
    topic_name         = string
  }))
  default = {
    "DeferredMessages-Complete" = {
      topic_name = "DeferredMessages"
      sql_filter = "ObjectType='DeferredMessage' AND Action='Complete'"
    }
    "DeferredMessages-Abandon" = {
      topic_name = "DeferredMessages"
      sql_filter = "ObjectType='DeferredMessage' AND Action='Abandon'"
    }
    "DeferredMessages-DeadLetter" = {
      topic_name = "DeferredMessages"
      sql_filter = "ObjectType='DeferredMessage' AND Action='DeadLetter'"
    }
    "EventNotification-Demo-HR-Employee" = {
      topic_name = "EventNotification"
      sql_filter = "ObjectType='Employee' AND sendingSystem='HRDemo'"
    }
    "EventNotification-Unknown" = {
      topic_name = "EventNotification"
      sql_filter = "ObjectType='Unknown'"
    }
    "Demo-Employee-Subscriber1" = {
      topic_name = "Demo-Employee"
      sql_filter = "ObjectType='Employee'"
    }
    "Demo-Employee-Subscriber2" = {
      topic_name = "Demo-Employee"
      sql_filter = "ObjectType='Employee' AND CountryCode='SE'"
    }
    "Demo-Deferred-Handler" = {
      topic_name = "Demo-Deferred"
      sql_filter = "ObjectType='Demo-Deferred'"
    }
    "Demo-Single-Deferred-Handler" = {
      topic_name = "Demo-Single-Deferred"
      sql_filter = "ObjectType='Demo-Single-Deferred'"
    }
    "Demo-Session-LongRunning-Handler" = {
      topic_name       = "Demo-Session-LongRunning"
      sql_filter       = "1=1"
      requires_session = true
    }
    "Demo-Session-Convoy-Handler" = {
      topic_name       = "Demo-Session-Convoy"
      sql_filter       = "1=1"
      requires_session = true
    }
  }
}

variable "pep_subnet_key" {
  description = "Key of the subnet (from int_network output subnet_ids) to attach private endpoints."
  type        = string
  default     = "snet-private-endpoints"
}

# ── Terraform State Backend ───────────────────────────────────────────────────
# These variables are used by data.terraform_remote_state blocks to read
# outputs from upstream stacks.

variable "tfstate_resource_group_name" {
  description = "Resource group that contains the Terraform state storage account."
  type        = string
}

variable "tfstate_storage_account_name" {
  description = "Storage account name for Terraform remote state."
  type        = string
}

variable "tfstate_container_name" {
  description = "Blob container name for Terraform state files."
  type        = string
  default     = "tfstate"
}
