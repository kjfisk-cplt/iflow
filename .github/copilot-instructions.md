# iflow — Workspace Guidelines

## Project Overview

**IFlow** is an Azure-based integration platform built with Infrastructure as Code using Terraform and Azure Verified Modules. The platform follows Zero Trust principles with private endpoints, managed identities, and modular domain-based design.

**Current State**: Infrastructure-first — Only networking module is implemented. Application code (`code/`) is planned but not yet scaffolded.

## Project Structure

| Folder                    | Purpose                                                                               |
| ------------------------- | ------------------------------------------------------------------------------------- |
| `code/`                   | Application source code (planned — currently empty)                                   |
| `infrastructure_as_code/` | Terraform / Azure IaC organized by environment and domain                             |
| `docs/`                   | Architecture documentation (Swedish) — see [ARCHITECTURE.md](../docs/ARCHITECTURE.md) |
| `.github/`                | Agent customizations (instructions, agents, skills)                                   |

## Architecture

**Integration Platform Components** (domain modules):

- **Network** (`int_network`) — VNet, NSG, 15 Private DNS zones, Private Link Scope ✅ Implemented
- **Monitoring** (`int_monitoring`) — Log Analytics, Application Insights, Action Groups
- **Common** (`int_common`) — Shared Managed Identity, App Service Plans
- **KeyVault** (`int_keyvault`) — Centralized secrets with Private Endpoints
- **Messaging** (`int_messaging`) — Event Hub, Service Bus for event-driven flows
- **Storage** (`int_storage`) — Blob, Queue, Table storage
- **Database** (`int_database`) — Azure SQL
- **APIM** (`int_apim`) — API Management as integration gateway
- **Functions/Logic** — Azure Functions (.NET) and Logic Apps Standard

**Design Principles**:

- **Zero Trust**: All PaaS resources use Private Endpoints within VNet
- **Managed Identity**: No connection strings; RBAC-based authentication
- **Independent Deployment**: Each domain module deploys separately
- **Centralized Naming**: Azure CAF naming conventions via `_shared/naming`

Full architecture: [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) (Swedish)

## Terraform Conventions

### File Structure (per stack)

```
infrastructure_as_code/environments/{env}/int_{domain}/
├── providers.tf      # Terraform & provider config + backend
├── variables.tf      # Input variables
├── terraform.tfvars  # Variable values (git-ignored)
├── locals.tf         # Computed local values
├── main.tf           # Resource definitions
└── outputs.tf        # Exported values
```

### Naming Patterns (Azure CAF)

```
rg-{workload}-{purpose}-{env}           # Resource groups
vnet-{workload}-integration-{env}       # Virtual networks
nsg-{workload}-integration-{env}        # Network security groups
sto{purpose}{workload}{env}             # Storage (no hyphens, max 24 chars)
pep-{service}-{workload}-{env}          # Private endpoints
```

Example: `rg-iflow-network-dev`

### Deployment Workflow

```bash
# Navigate to stack
cd infrastructure_as_code/environments/dev/int_network

# Initialize with backend
terraform init -backend-config="../backend.conf" -backend-config="key=int_network.tfstate"

# Plan changes
terraform plan -var-file="terraform.tfvars"

# Apply (after review)
terraform apply -var-file="terraform.tfvars"
```

### Required Providers

- `azurerm` ~> 4.0
- `azapi` ~> 2.4 (required for AVM VNet module)
- Telemetry disabled on all AVM modules: `enable_telemetry = false`

### Variable Standards

- **Required**: `subscription_id` (sensitive), `workload`, `env`, `location`
- **Environment validation**: Must be `dev`, `test`, or `prod`
- **Default location**: `swedencentral`
- **Shared naming**: All stacks use `module.naming` from `_shared/naming`

## Code Style

- Terraform: Follow HashiCorp HCL style guide
- Use Azure Verified Modules (AVM) from registry when available
- Centralize all resource naming through `_shared/naming` module
- Tag all resources via `local.tags` from naming module

## Build and Test

**Infrastructure**:

```bash
# Validate Terraform syntax
terraform fmt -check -recursive

# Validate configuration
terraform validate

# Security scan (if available)
# tfsec infrastructure_as_code/
```

**Application**: Not yet implemented — `code/` directory is empty

## Conventions

- **Minimal, surgical changes** — Only modify what's required
- **Verify with tools** — Prefer current data over assumptions
- **Declare intent** — Especially for destructive operations
- **Plan before apply** — Always review `terraform plan` output
- **No secrets in source** — Sensitive values in Key Vault or `terraform.tfvars` (git-ignored)
- **Cross-stack dependencies** — Use `terraform_remote_state` when modules reference each other
- **Backend key management** — Each stack requires unique backend key

## Known Issues

- **Typo**: `_shared/vaiables.tf` should be `variables.tf`
- **Incomplete modules**: Only `int_network` is implemented; 10 other modules are scaffolded but empty
- **No deployment docs**: No README or automation scripts for Terraform workflow
- **No build/test for app**: Application layer not yet started
