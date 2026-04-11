---
name: scaffold-terraform-module
description: "Generate a new Terraform integration module from the stack template following iflow naming conventions and structure. Use when: create terraform module, scaffold terraform stack, new infrastructure module, new int_ module."
parameters:
  - name: module_name
    type: string
    description: "Module name without 'int_' prefix (e.g., 'keyvault', 'storage', 'messaging')"
    required: true
  - name: environment
    type: string
    description: "Target environment: dev, test, or prod"
    required: true
    default: "dev"
  - name: purpose
    type: string
    description: "Short description of module's purpose (e.g., 'Central secrets management')"
    required: true
---

# Scaffold Terraform Module

Generate a complete Terraform integration module following iflow conventions.

## Input Validation

Validate parameters:

- **module_name**: Lowercase alphanumeric and hyphens only, 2-20 chars
- **environment**: Must be `dev`, `test`, or `prod`
- **purpose**: Required, will be used in documentation

## Module Structure

Create the following files in `infrastructure_as_code/environments/{{environment}}/int_{{module_name}}/`:

### 1. providers.tf

```hcl
terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "azurerm" {
    # Backend configured via -backend-config at init:
    # terraform init \
    #   -backend-config="../backend.conf" \
    #   -backend-config="key=int_{{module_name}}.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
  subscription_id = var.subscription_id
}

provider "azapi" {
  subscription_id = var.subscription_id
}
```

### 2. variables.tf

```hcl
# Core Variables
variable "subscription_id" {
  type        = string
  sensitive   = true
  description = "Azure subscription ID"
}

variable "workload" {
  type        = string
  description = "Workload name (2-20 chars, lowercase alphanumeric + hyphens)"
  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.workload))
    error_message = "Workload must be 2-20 lowercase alphanumeric characters or hyphens"
  }
}

variable "env" {
  type        = string
  description = "Environment: dev, test, or prod"
  validation {
    condition     = contains(["dev", "test", "prod"], var.env)
    error_message = "Environment must be dev, test, or prod"
  }
}

variable "location" {
  type        = string
  default     = "swedencentral"
  description = "Azure region for resources"
}

# Backend State Variables (for cross-stack references)
variable "tfstate_resource_group_name" {
  type        = string
  description = "Resource group containing Terraform state storage"
}

variable "tfstate_storage_account_name" {
  type        = string
  description = "Storage account for Terraform state"
}

variable "tfstate_container_name" {
  type        = string
  description = "Container name for Terraform state"
}

# TODO: Add module-specific variables here
```

### 3. terraform.tfvars

```hcl
# Core Configuration
subscription_id = "00000000-0000-0000-0000-000000000000" # TODO: Replace with actual subscription ID
workload        = "iflow"
env             = "{{environment}}"
location        = "swedencentral"

# Terraform State Backend
tfstate_resource_group_name  = "rg-tfstate-iflow"
tfstate_storage_account_name = "stoterraformstate"
tfstate_container_name       = "tfstate"

# TODO: Add module-specific variable values here
```

**⚠️ IMPORTANT**: Add to `.gitignore` if it contains sensitive values!

### 4. locals.tf

```hcl
locals {
  # Centralized tagging via naming module
  tags = module.naming.common_tags

  # Module-specific locals
  # TODO: Add computed values, merged configurations, etc.
}
```

### 5. main.tf

```hcl
# ============================================================================
# INT-{{module_name | upper}} - {{purpose}}
# ============================================================================

# Naming Convention Module
module "naming" {
  source   = "../_shared/naming"
  workload = var.workload
  env      = var.env
  location = var.location
}

# Resource Group
resource "azurerm_resource_group" "{{module_name}}" {
  name     = module.naming.resource_group["{{module_name}}"]
  location = var.location
  tags     = local.tags
}

# Remote State: Network (for VNet references)
data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = "int_network.tfstate"
  }
}

# Subnet Reference (if private endpoints needed)
data "azurerm_subnet" "privateendpoint" {
  name                 = "privateendpoint"
  virtual_network_name = data.terraform_remote_state.network.outputs.vnet_name
  resource_group_name  = data.terraform_remote_state.network.outputs.resource_group_name
}

# Private DNS Zone Reference (if private endpoints needed)
# Uncomment and modify based on service type:
# data "azurerm_private_dns_zone" "service" {
#   name                = "privatelink.{service}.azure.net"
#   resource_group_name = data.terraform_remote_state.network.outputs.resource_group_name
# }

# TODO: Add main resources here
# Example structure:
# 1. Create main service resource
# 2. Create private endpoint (if PaaS)
# 3. Configure RBAC (if needed)
# 4. Create child resources
```

### 6. outputs.tf

```hcl
# Resource Group
output "resource_group_name" {
  description = "Name of the {{module_name}} resource group"
  value       = azurerm_resource_group.{{module_name}}.name
}

output "resource_group_id" {
  description = "ID of the {{module_name}} resource group"
  value       = azurerm_resource_group.{{module_name}}.id
}

# TODO: Add module-specific outputs here
# Best practices:
# - Export IDs (not names) for resource references
# - Mark sensitive values with `sensitive = true`
# - Include outputs needed by dependent modules
```

### 7. README.md (optional but recommended)

````markdown
# INT-{{module_name | upper}}

{{purpose}}

## Purpose

[Detailed description of the module's role in the integration platform]

## Resources Created

- Resource Group: `rg-iflow-{{module_name}}-{{environment}}`
- [List main resources]

## Dependencies

**Required modules** (must be deployed first):

- `int_network` - Provides VNet and Private DNS zones

**Optional modules**:

- `int_common` - For shared Managed Identity

## Deployment

```bash
# Navigate to module
cd infrastructure_as_code/environments/{{environment}}/int_{{module_name}}

# Initialize (first time only)
terraform init \
  -backend-config="../backend.conf" \
  -backend-config="key=int_{{module_name}}.tfstate"

# Plan changes
terraform plan -var-file="terraform.tfvars"

# Apply (after reviewing plan)
terraform apply -var-file="terraform.tfvars"
```
````

## Configuration

### Required Variables

See [terraform.tfvars](terraform.tfvars) for configuration options.

### Cross-Stack References

This module references:

- `int_network` state for VNet and subnet IDs

## Outputs

[List key outputs and their purpose]

## Security

- All PaaS resources use Private Endpoints
- Managed Identity for authentication (no connection strings)
- Secrets stored in Key Vault (not in code)
- Network isolation via NSG rules

## Known Issues

[Document any known limitations or issues]

## Future Enhancements

[List planned improvements]

````

## Post-Scaffolding Tasks

After creating the module structure:

1. **Update terraform.tfvars**:
   - Replace placeholder subscription ID
   - Add any module-specific configuration

2. **Review dependencies**:
   - Verify `int_network` is deployed
   - Add other dependencies if needed (common, keyvault, etc.)

3. **Implement main resources**:
   - Add Azure resources in `main.tf`
   - Follow Zero Trust principles (Private Endpoints)
   - Use Managed Identity for authentication
   - Tag all resources via `local.tags`

4. **Add module-specific variables**:
   - Define in `variables.tf`
   - Set values in `terraform.tfvars`

5. **Define outputs**:
   - Export resource IDs for dependent modules
   - Mark sensitive values appropriately

6. **Initialize Terraform**:
   ```bash
   terraform init \
     -backend-config="../backend.conf" \
     -backend-config="key=int_{{module_name}}.tfstate"
````

7. **Validate**:
   ```bash
   terraform fmt
   terraform validate
   ```

## Example Modules

Reference existing implemented modules:

- `int_network/` - Complete example with VNet, NSG, Private DNS

## Next Steps

Once scaffolding is complete:

1. Review the generated files
2. Update `TODO` comments with actual implementation
3. Test initialization: `terraform init`
4. Document any module-specific conventions
5. Add to deployment order in documentation

---

**Module scaffolded**: `int_{{module_name}}`  
**Environment**: `{{environment}}`  
**Location**: `infrastructure_as_code/environments/{{environment}}/int_{{module_name}}/`

Ready to implement module-specific resources!

````

## Workflow

1. **Validate inputs** (module_name, environment, purpose)
2. **Create directory** structure
3. **Generate all files** from templates above
4. **Replace placeholders** with parameter values
5. **Present summary** of created files
6. **Provide next steps** checklist

## Output Summary

After scaffolding, present:

```markdown
## ✅ Module Scaffolded: int_{{module_name}}

Created in: `infrastructure_as_code/environments/{{environment}}/int_{{module_name}}/`

### Files Created
- ✅ providers.tf (Terraform, azurerm, azapi config)
- ✅ variables.tf (Core + state backend variables)
- ✅ terraform.tfvars (Configuration values)
- ✅ locals.tf (Tags and computed values)
- ✅ main.tf (Resource group + remote state references)
- ✅ outputs.tf (Resource group outputs)
- ✅ README.md (Deployment documentation)

### Next Steps

1. **Update configuration**:
   - [ ] Edit `terraform.tfvars` - replace subscription ID
   - [ ] Add module-specific variables if needed

2. **Implement resources**:
   - [ ] Add main Azure resources to `main.tf`
   - [ ] Follow Private Endpoint pattern for PaaS
   - [ ] Use Managed Identity (reference from int_common)

3. **Define outputs**:
   - [ ] Export resource IDs in `outputs.tf`
   - [ ] Mark sensitive values appropriately

4. **Initialize & validate**:
   ```bash
   cd infrastructure_as_code/environments/{{environment}}/int_{{module_name}}
   terraform init -backend-config="../backend.conf" -backend-config="key=int_{{module_name}}.tfstate"
   terraform fmt
   terraform validate
````

5. **Deploy**:
   - Use `/terraform-deployer` for safe deployment workflow

Would you like me to help implement the main resources for this module?

```

```
