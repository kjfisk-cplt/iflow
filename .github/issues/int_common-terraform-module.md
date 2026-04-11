# [IaC] Create int_common Terraform Module

## Overview

Create the shared infrastructure module for the IFlow integration platform. This module provisions centralized resources that are consumed by multiple domain modules, including a User Assigned Managed Identity for all workloads and shared App Service Plans for Azure Functions, Logic Apps, and Web Apps.

**Module Name:** `int_common`  
**Target Path:** `infrastructure_as_code/environments/dev/int_common/`  
**Priority:** High

---

## Resources to Create

| Resource | Type | Naming Convention |
|----------|------|-------------------|
| Resource Group | `azurerm_resource_group` | `rg-iflow-common-{env}` |
| User Assigned Managed Identity | AVM `avm-res-managedidentity-userassignedidentity` | `id-iflow-common-{env}` |
| App Service Plan (Functions) | AVM `avm-res-web-serverfarm` | `asp-iflow-common-func-{env}` |
| App Service Plan (Logic Apps) | AVM `avm-res-web-serverfarm` | `asp-iflow-common-la-{env}` |
| App Service Plan (Web Apps) | AVM `avm-res-web-serverfarm` | `asp-iflow-common-web-{env}` |

---

## Configuration

### SKU / Tier Settings

| Resource | Dev/Test | Prod |
|----------|----------|------|
| App Service Plan (Functions) | B1 (Basic) | P1v3 (Premium) |
| App Service Plan (Logic Apps) | WS1 (Workflow Standard) | WS2 (Workflow Standard) |
| App Service Plan (Web Apps) | B1 (Basic) | P1v3 (Premium) |

### Variables

```hcl
# Standard variables (from _shared pattern)
variable "subscription_id" {
  type      = string
  sensitive = true
}

variable "workload" {
  type    = string
  default = "iflow"
}

variable "env" {
  type = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.env)
    error_message = "Environment must be dev, test, or prod."
  }
}

variable "location" {
  type    = string
  default = "swedencentral"
}

# Module-specific variables
variable "asp_functions_sku" {
  description = "SKU for Functions App Service Plan"
  type        = string
  default     = "B1"
}

variable "asp_logic_sku" {
  description = "SKU for Logic Apps App Service Plan"
  type        = string
  default     = "WS1"
}

variable "asp_web_sku" {
  description = "SKU for Web Apps App Service Plan"
  type        = string
  default     = "B1"
}
```

### Outputs

```hcl
output "resource_group_name" {
  description = "Name of the common resource group"
  value       = azurerm_resource_group.common.name
}

output "resource_group_id" {
  description = "ID of the common resource group"
  value       = azurerm_resource_group.common.id
}

output "managed_identity_id" {
  description = "ID of the User Assigned Managed Identity"
  value       = module.managed_identity.resource_id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the User Assigned Managed Identity"
  value       = module.managed_identity.principal_id
}

output "managed_identity_client_id" {
  description = "Client ID of the User Assigned Managed Identity"
  value       = module.managed_identity.client_id
}

output "asp_functions_id" {
  description = "ID of the Functions App Service Plan"
  value       = module.asp_functions.resource_id
}

output "asp_logic_id" {
  description = "ID of the Logic Apps App Service Plan"
  value       = module.asp_logic.resource_id
}

output "asp_web_id" {
  description = "ID of the Web Apps App Service Plan"
  value       = module.asp_web.resource_id
}
```

---

## Implementation Requirements

- [x] Use Azure Verified Modules (AVM) where available
- [x] Reference `module.naming` from `../_shared/naming`
- [x] Use `local.tags` from naming module
- [x] Set `enable_telemetry = false` on all AVM modules
- [x] Follow existing patterns from reference module

**Reference Module:** `infrastructure_as_code/environments/dev/int_network/`

### Provider Requirements

```hcl
terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
  backend "azurerm" {}
}

provider "azurerm" {
  subscription_id     = var.subscription_id
  storage_use_azuread = true
  features {}
}
```

### File Structure

```
int_common/
├── providers.tf      # Terraform & provider config + backend
├── variables.tf      # Input variables
├── terraform.tfvars  # Variable values (git-ignored)
├── locals.tf         # Computed local values
├── main.tf           # Resource definitions
└── outputs.tf        # Exported values
```

---

## Dependencies

**Depends on:**
- `_shared/naming` (for resource naming conventions)

**Consumed by:**
- `int_keyvault` (uses managed identity for Key Vault access)
- `int_functions` (uses Functions App Service Plan and managed identity)
- `int_logic` (uses Logic Apps App Service Plan and managed identity)
- `int_monitoring` (uses managed identity for telemetry access)
- `int_apim` (uses managed identity for backend authentication)

---

## Acceptance Criteria

- [ ] `terraform validate` passes
- [ ] `terraform plan` shows expected 5 resources
- [ ] All resources use centralized naming via `module.naming`
- [ ] All resources tagged via `local.tags`
- [ ] Outputs expose IDs needed by downstream modules
- [ ] No hardcoded values (all configurable via variables)
- [ ] Code follows HashiCorp HCL style guide
- [ ] Works with existing `backend.conf` configuration
- [ ] User Assigned Managed Identity created with correct naming
- [ ] All three App Service Plans created with environment-appropriate SKUs
- [ ] App Service Plans configured as:
  - Functions plan: `kind = "FunctionApp"`, `os_type = "Windows"`
  - Logic Apps plan: `kind = "elastic"` (WorkflowStandard)
  - Web Apps plan: `kind = "Windows"`

---

## Additional Context

This module implements **Section 5 (INT-Common)** from the architecture document. The User Assigned Managed Identity is a central component for the Zero Trust architecture, enabling passwordless authentication across all integration workloads.

**Architecture Reference:** [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md)

### AVM Module References

- [User Assigned Identity](https://registry.terraform.io/modules/Azure/avm-res-managedidentity-userassignedidentity/azurerm/latest)
- [App Service Plan](https://registry.terraform.io/modules/Azure/avm-res-web-serverfarm/azurerm/latest)
