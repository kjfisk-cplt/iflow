# IFlow – Azure Integration Platform

[![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/Cloud-Azure-0078D4?logo=microsoft-azure)](https://azure.microsoft.com/)
[![Zero Trust](https://img.shields.io/badge/Security-Zero%20Trust-green)](https://www.microsoft.com/security/business/zero-trust)

IFlow is an Azure-based integration platform built with Infrastructure as Code using Terraform and Azure Verified Modules. The platform follows Zero Trust principles with private endpoints, managed identities, and modular domain-based design.

## 🎯 Project Overview

IFlow provides a secure, scalable integration platform for connecting internal and external systems through:

- **API Management** as the integration gateway
- **Logic Apps Standard** for workflow orchestration
- **Azure Functions (.NET Isolated)** for technical processing
- **Event-driven architecture** with Service Bus and Event Hub
- **Centralized monitoring** with Application Insights and Log Analytics

**Current State**: Infrastructure-first development phase. The networking and monitoring modules are implemented; application code layer is planned for future phases.

## 🏗️ Architecture

IFlow follows a **modular domain-based architecture** where each integration domain can be developed, deployed, and managed independently while sharing common platform services.

### Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                    Integration Domains                       │
│  (HR, Finance, SAP, CRM - Logic Apps & Functions)           │
├─────────────────────────────────────────────────────────────┤
│              Integration Gateway (API Management)            │
├─────────────────────────────────────────────────────────────┤
│         Platform Services (Messaging, Storage, DB)           │
├─────────────────────────────────────────────────────────────┤
│    Foundation (Network, Monitoring, Identity, KeyVault)      │
└─────────────────────────────────────────────────────────────┘
```

### Domain Modules

| Module | Purpose | Status |
|--------|---------|--------|
| `int_network` | VNet, NSG, 15 Private DNS zones, Private Link Scope | ✅ Implemented |
| `int_monitoring` | Log Analytics, Application Insights, Action Groups | ✅ Implemented |
| `int_common` | Shared Managed Identity, App Service Plans | 📋 Planned |
| `int_keyvault` | Centralized secrets with Private Endpoints | 📋 Planned |
| `int_messaging` | Event Hub, Service Bus for event-driven flows | 📋 Planned |
| `int_storage` | Blob, Queue, Table storage | 📋 Planned |
| `int_database` | Azure SQL | 📋 Planned |
| `int_apim` | API Management as integration gateway | 📋 Planned |
| `int_functions` | Azure Functions (.NET) | 📋 Planned |
| `int_logicapps` | Logic Apps Standard | 📋 Planned |

### Design Principles

- **🔒 Zero Trust**: All PaaS resources use Private Endpoints within VNet (no public access)
- **🔑 Managed Identity**: No connection strings; RBAC-based authentication only
- **🔄 Independent Deployment**: Each domain module deploys separately
- **🏷️ Centralized Naming**: Azure CAF naming conventions via `_shared/naming` modules
- **📊 Observability First**: Comprehensive logging, tracing, and monitoring

For detailed architecture documentation, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (Swedish).

## 🛠️ Technology Stack

### Infrastructure as Code

- **Terraform** >= 1.9
- **Azure Provider** (`azurerm`) ~> 4.0
- **Azure API Provider** (`azapi`) ~> 2.4
- **Azure Verified Modules (AVM)** from Terraform Registry

### Azure Services

- Azure Virtual Network (VNet)
- Azure Monitor & Application Insights
- Azure Key Vault
- Azure Service Bus & Event Hub
- Azure Storage (Blob, Queue, Table)
- Azure SQL Database
- Azure API Management
- Azure Functions (.NET Isolated)
- Azure Logic Apps Standard

### Development Tools

- **PowerShell** >= 7.0 (automation scripts)
- **Azure CLI** >= 2.50.0
- **Git** for version control
- **Visual Studio Code** with recommended extensions

## 📁 Project Structure

```
iflow/
├── .github/                      # GitHub Actions workflows, Copilot agents & instructions
│   ├── workflows/                # CI/CD pipelines
│   ├── instructions/             # Domain-specific guidance for agents
│   └── copilot-instructions.md   # Main workspace guidelines
├── code/                         # Application source code (planned, not yet scaffolded)
├── docs/                         # Architecture documentation (Swedish)
│   ├── ARCHITECTURE.md           # Complete platform architecture
│   └── Diagrams/                 # Mermaid diagrams and exports
├── infrastructure_as_code/       # Terraform IaC
│   ├── environments/             # Environment-specific configurations
│   │   ├── dev/                  # Development environment
│   │   │   ├── int_network/      # Network module stack
│   │   │   ├── int_monitoring/   # Monitoring module stack
│   │   │   └── ...               # Other domain modules
│   │   ├── test/                 # Test environment
│   │   ├── prod/                 # Production environment
│   │   └── _shared/              # Shared modules (naming, utilities)
│   ├── scripts/                  # PowerShell automation scripts
│   └── docs/                     # IaC operational guides
└── iflow.code-workspace          # VS Code workspace settings
```

## 🚀 Getting Started

### Prerequisites

1. **Azure Subscription** with Contributor access
2. **Azure CLI** >= 2.50.0
   ```powershell
   winget install Microsoft.AzureCLI
   ```
3. **Terraform** >= 1.9
   ```powershell
   winget install Hashicorp.Terraform
   ```
4. **PowerShell** >= 7.0
   ```powershell
   winget install Microsoft.PowerShell
   ```

### Initial Setup

#### 1. Bootstrap Terraform State Storage

Create Azure Storage backend for Terraform state (one-time setup per environment):

```powershell
cd infrastructure_as_code/scripts

# Dev environment
.\bootstrap-state-storage.ps1 `
  -Environment dev `
  -SubscriptionId "your-subscription-id"

# Test environment
.\bootstrap-state-storage.ps1 `
  -Environment test `
  -SubscriptionId "your-subscription-id"

# Production environment
.\bootstrap-state-storage.ps1 `
  -Environment prod `
  -SubscriptionId "your-subscription-id"
```

#### 2. Configure OIDC for GitHub Actions (Optional)

For CI/CD deployments using GitHub Actions:

```powershell
.\configure-oidc.ps1 `
  -SubscriptionId "your-subscription-id" `
  -GitHubOrg "kjfisk-cplt" `
  -GitHubRepo "iflow"
```

Add the output secrets to GitHub repository settings.

#### 3. Deploy Network Module

```powershell
cd ../environments/dev/int_network

# Create terraform.tfvars (copy from template and fill in values)
# See terraform.tfvars.example for required variables

# Initialize Terraform with remote backend
terraform init `
  -backend-config="../backend.conf" `
  -backend-config="key=int_network.tfstate"

# Review planned changes
terraform plan -var-file="terraform.tfvars"

# Apply infrastructure
terraform apply -var-file="terraform.tfvars"
```

#### 4. Deploy Monitoring Module

```powershell
cd ../int_monitoring

# Create terraform.tfvars
# Initialize and apply same as network module

terraform init `
  -backend-config="../backend.conf" `
  -backend-config="key=int_monitoring.tfstate"

terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

### Environment Configuration

Each environment requires a `terraform.tfvars` file (git-ignored) with:

```hcl
subscription_id = "your-subscription-id"
workload        = "iflow"
env             = "dev"  # or "test", "prod"
location        = "swedencentral"
```

**⚠️ Never commit `terraform.tfvars` to source control** – it may contain sensitive information.

## 🔧 Development Workflow

### Terraform Workflow

1. **Navigate to module stack**
   ```bash
   cd infrastructure_as_code/environments/{env}/int_{domain}
   ```

2. **Initialize Terraform**
   ```bash
   terraform init -backend-config="../backend.conf" -backend-config="key=int_{domain}.tfstate"
   ```

3. **Plan changes**
   ```bash
   terraform plan -var-file="terraform.tfvars"
   ```

4. **Apply changes** (after review)
   ```bash
   terraform apply -var-file="terraform.tfvars"
   ```

### Code Quality Checks

```bash
# Format Terraform code
terraform fmt -check -recursive

# Validate configuration
terraform validate

# Security scan (if tfsec available)
tfsec infrastructure_as_code/
```

### Naming Conventions

All Azure resources follow **Azure Cloud Adoption Framework (CAF)** naming conventions:

**Platform resources** (Network, Monitoring, Common):
- Resource groups: `rg-{workload}-{purpose}-{env}`
- VNets: `vnet-{workload}-integration-{env}`
- Storage: `sto{purpose}{workload}{env}`

**Domain resources** (HR, Finance, SAP):
- Resource groups: `rg-{workload}-{domain}-{env}`
- Logic Apps: `logic-{workload}-{domain}-{env}`
- Functions: `func-{workload}-{domain}-{purpose}-{env}`

Names are generated by the centralized `_shared/naming` or `_shared/naming-domain` modules.

## 📝 Coding Standards

### Terraform Conventions

- **Use Azure Verified Modules (AVM)** from Terraform Registry where available
- **Pin module versions** using semantic versioning (`version = "~> 1.0"`)
- **Disable telemetry** on all AVM modules: `enable_telemetry = false`
- **Use Managed Identity** for authentication (never hardcode credentials)
- **All PaaS resources** must use Private Endpoints (Zero Trust requirement)
- **Follow HashiCorp HCL style guide**
- **Centralize naming** through shared naming modules

### File Structure (per stack)

```
int_{domain}/
├── providers.tf      # Terraform & provider config + backend
├── variables.tf      # Input variables with validation
├── terraform.tfvars  # Variable values (git-ignored)
├── locals.tf         # Computed local values
├── main.tf           # Resource definitions
└── outputs.tf        # Exported values
```

### Required Providers

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
  }
}
```

**Note**: `azapi` provider is required for Azure Verified Modules.

## 🧪 Testing

### Infrastructure Validation

```bash
# Format check
terraform fmt -check -recursive

# Syntax validation
terraform validate

# Security scanning (if available)
tfsec infrastructure_as_code/
```

### Plan Review

Always review `terraform plan` output before applying changes:

```bash
terraform plan -var-file="terraform.tfvars" -out=tfplan
# Review output carefully
terraform apply tfplan
```

## 📚 Documentation

### Architecture & Design

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Complete platform architecture (Swedish)
- **[.github/copilot-instructions.md](.github/copilot-instructions.md)** - Workspace guidelines and conventions

### Infrastructure Guides

- **[infrastructure_as_code/scripts/README.md](infrastructure_as_code/scripts/README.md)** - Automation scripts documentation
- **[infrastructure_as_code/docs/](infrastructure_as_code/docs/)** - IaC operational guides

### GitHub Copilot Instructions

Domain-specific guidance for AI assistants:
- **[.github/instructions/terraform-conventions.instructions.md](.github/instructions/terraform-conventions.instructions.md)** - Terraform best practices
- **[.github/instructions/terraform-azure.instructions.md](.github/instructions/terraform-azure.instructions.md)** - Azure-specific patterns
- **[.github/instructions/azure-verified-modules-terraform.instructions.md](.github/instructions/azure-verified-modules-terraform.instructions.md)** - AVM usage guidelines

## 🤝 Contributing

### Before Making Changes

1. Read [.github/copilot-instructions.md](.github/copilot-instructions.md) for project conventions
2. Review relevant documentation in `docs/` and `.github/instructions/`
3. Ensure you have appropriate Azure permissions

### Making Changes

1. Create a feature branch from `main`
2. Make minimal, surgical changes
3. Update documentation if needed (see Documentation Requirements in copilot-instructions.md)
4. Run validation: `terraform fmt` and `terraform validate`
5. Test in `dev` environment first
6. Create pull request with clear description

### Documentation Requirements

When making changes, check if these documents need updates:

| Change Type | Documentation to Update |
|-------------|-------------------------|
| New Terraform module | `docs/ARCHITECTURE.md`, `copilot-instructions.md` |
| New/modified scripts | `infrastructure_as_code/scripts/README.md` |
| Architecture decisions | `docs/ARCHITECTURE.md` |
| New variables/outputs | Module inline comments, naming modules |
| Conventions changes | `copilot-instructions.md`, `.github/instructions/*.md` |

## 🔐 Security

### Zero Trust Architecture

- **All PaaS resources** use Private Endpoints (no public access)
- **No hardcoded credentials** - use Managed Identity and RBAC
- **Secrets in Azure Key Vault** - never in source code or Terraform state
- **Network isolation** - all resources within VNet
- **Least privilege access** - RBAC roles scoped appropriately

### Secure Practices

- Mark sensitive variables as `sensitive = true`
- Use `terraform.tfvars` (git-ignored) for environment-specific values
- Never commit secrets or subscription IDs to source control
- Use OIDC for GitHub Actions (no long-lived credentials)
- Review `terraform plan` output before applying

## 🗺️ Roadmap

### Phase 1: Foundation (Current)
- ✅ Network infrastructure (VNet, subnets, DNS zones)
- ✅ Monitoring platform (Log Analytics, Application Insights)
- 📋 Common platform services (Managed Identity, App Service Plans)
- 📋 Key Vault with private endpoints

### Phase 2: Platform Services
- 📋 Messaging infrastructure (Service Bus, Event Hub)
- 📋 Storage services (Blob, Queue, Table)
- 📋 Database services (Azure SQL)
- 📋 API Management gateway

### Phase 3: Integration Domains
- 📋 Logic Apps Standard for workflow orchestration
- 📋 Azure Functions (.NET) for processing
- 📋 Domain-specific integration flows
- 📋 Application code in `code/` directory

## 📄 License

Copyright © 2024-2026 IFlow Platform Team

*License information to be added.*

## 🆘 Support

For questions, issues, or contributions:

1. Check [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for architecture details
2. Review [.github/copilot-instructions.md](.github/copilot-instructions.md) for conventions
3. Open an issue in the GitHub repository
4. Contact the IFlow Platform Team

---

**Built with** ❤️ **using Terraform, Azure, and Zero Trust principles**
