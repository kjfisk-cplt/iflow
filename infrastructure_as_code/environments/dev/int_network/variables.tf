variable "subscription_id" {
  description = "Azure subscription ID where resources are deployed."
  type        = string
  sensitive   = true
}

variable "workload" {
  description = "Workload / customer abbreviation used in all resource names (e.g. \"iflow\")."
  type        = string
}

variable "env" {
  description = "Deployment environment. Allowed values: dev, test, prod."
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

variable "vnet_address_space" {
  description = "CIDR address space(s) for the integration virtual network."
  type        = set(string)
  default     = ["10.0.0.0/16"]
}

variable "subnets" {
  description = "Map of subnet configurations to create inside the virtual network."
  type = map(object({
    address_prefixes                              = list(string)
    private_endpoint_network_policies             = optional(string, "Disabled")
    private_link_service_network_policies_enabled = optional(bool, false)
    service_endpoints = optional(list(object({
      service   = string
      locations = optional(list(string), ["*"])
    })), [])
    delegations = optional(list(object({
      name = string
      service_delegation = object({
        name = string
      })
    })), [])
  }))

  default = {
    "snet-private-endpoints" = {
      address_prefixes                  = ["10.0.0.0/24"]
      private_endpoint_network_policies = "Disabled"
    }
    "snet-integration" = {
      address_prefixes = ["10.0.1.0/24"]
      delegations = [{
        name = "delegation-webfarm"
        service_delegation = {
          name = "Microsoft.Web/serverFarms"
        }
      }]
    }
    "snet-apim" = {
      address_prefixes = ["10.0.2.0/24"]
    }
  }
}

variable "private_dns_zones" {
  description = "Set of private DNS zone names to create and link to the VNet."
  type        = set(string)
  default = [
    "privatelink.azurewebsites.net",
    "privatelink.applicationinsights.azure.com",
    "privatelink.blob.core.windows.net",
    "privatelink.vaultcore.azure.net",
    "privatelink.ods.opinsights.azure.com",
    "privatelink.monitor.azure.com",
    "privatelink.oms.opinsights.azure.com",
    "privatelink.servicebus.windows.net",
    "privatelink.agentsvc.azure-automation.net",
    "privatelink.eventgrid.azure.net",
    "privatelink.file.core.windows.net",
    "privatelink.table.core.windows.net",
    "privatelink.queue.core.windows.net",
    "privatelink.azure-api.net",
    "privatelink.database.windows.net",
  ]
}

variable "pep_monitoring_subnet_key" {
  description = "Key of the subnet (from the subnets map) to attach the monitoring private endpoint."
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
