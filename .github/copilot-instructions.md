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
- **Monitoring** (`int_monitoring`) — Log Analytics, Application Insights, Action Groups ✅ Implemented
- **Common** (`int_common`) — Shared Managed Identity, App Service Plans ✅ Implemented
- **KeyVault** (`int_keyvault`) — Centralized secrets with Private Endpoints ✅ Implemented
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

**Two naming modules** for different scopes:

| Module                  | Scope               | When to Use                                                       |
| ----------------------- | ------------------- | ----------------------------------------------------------------- |
| `_shared/naming`        | Platform resources  | VNet, NSG, APIM, shared Key Vault, common App Service Plans       |
| `_shared/naming-domain` | Domain integrations | HR, Finance, SAP — system-specific Logic Apps, Functions, Storage |

**Platform naming** (`_shared/naming`):

```
rg-{workload}-{purpose}-{env}           # rg-iflow-network-dev
vnet-{workload}-integration-{env}       # vnet-iflow-integration-dev
sto{purpose}{workload}{env}             # stomaboringiflowdev
```

**Domain naming** (`_shared/naming-domain`):

```
rg-{workload}-{domain}-{env}            # rg-iflow-hr-dev
logic-{workload}-{domain}-{env}         # logic-iflow-hr-dev
func-{workload}-{domain}-{purpose}-{env}   # func-iflow-hr-validatedata-dev
sto{domain}{workload}{env}              # stohriflowdev
```

**Usage**:

```hcl
# Platform stack (int_network, int_common)
module "naming" {
  source = "../_shared/naming"
  # ... workload, env, location
}

# Domain stack (int_hr, int_finance)
module "naming" {
  source = "../_shared/naming-domain"
  domain = "hr"  # Additional variable
  # ... workload, env, location
}
```

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
- **Shared naming**: Platform stacks use `_shared/naming`; domain stacks use `_shared/naming-domain`

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
- **Workspace settings over config files** — Put linter/tool configs (markdownlint, eslint) in `iflow.code-workspace` settings, not separate files in root

## Documentation Requirements

**Principle**: Any meaningful code change requires a documentation check. This applies to all changes, not just specific categories.

### When Making Changes, Always Check

| Change Type            | Documentation to Review/Update                                             |
| ---------------------- | -------------------------------------------------------------------------- |
| New Terraform module   | `docs/ARCHITECTURE.md`, `copilot-instructions.md` (Architecture section)   |
| New/modified scripts   | `infrastructure_as_code/docs/TERRAFORM_STATE_SETUP.md`, script `README.md` |
| New variables/outputs  | Module's inline comments, `_shared/naming` or `_shared/naming-domain`      |
| Architecture decisions | `docs/ARCHITECTURE.md`, relevant Mermaid diagrams in `docs/Diagrams/`      |
| New dependencies       | `providers.tf` comments, `copilot-instructions.md` (Required Providers)    |
| Conventions changes    | `copilot-instructions.md`, `.github/instructions/*.md`                     |
| Agent customizations   | Relevant `.agent.md`, `.instructions.md`, or `SKILL.md` files              |

### Documentation Locations

| Document                                   | Purpose                         | Update When                          |
| ------------------------------------------ | ------------------------------- | ------------------------------------ |
| `docs/ARCHITECTURE.md`                     | Platform architecture (Swedish) | Adding modules, changing design      |
| `.github/copilot-instructions.md`          | Agent workspace context         | Any structural/convention change     |
| `.github/instructions/*.md`                | Domain-specific guidance        | Tool/pattern changes                 |
| `infrastructure_as_code/docs/*.md`         | IaC operational guides          | Script, workflow, or process changes |
| `infrastructure_as_code/scripts/README.md` | Script usage reference          | Adding/modifying scripts             |

### Agent Responsibility

When completing any task:

1. **Before finishing**: Check if documentation needs updating
2. **Proactively ask**: "Should I update any documentation for this change?"
3. **Update inline**: Include doc updates in the same task when obvious
4. **Flag for review**: Note any docs that may need human review

## Known Issues

- **Typo**: `_shared/vaiables.tf` should be `variables.tf`
- **Incomplete modules**: `int_network`, `int_monitoring`, `int_common`, `int_keyvault` are implemented; remaining modules are scaffolded but empty
- **No deployment docs**: No README or automation scripts for Terraform workflow
- **No build/test for app**: Application layer not yet started
