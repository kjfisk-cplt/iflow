# Terraform State Backend Setup

## Overview

This document explains the Terraform remote state configuration for the iFlow integration platform. The state backend uses Azure Storage with separate storage accounts per environment to ensure complete security isolation and align with Zero Trust principles.

## Architecture

- **Pattern**: Separate storage accounts per environment (dev, test, prod)
- **Storage**: Azure Storage with blob versioning and soft delete
- **Security**: RBAC-based access, HTTPS-only, TLS 1.2+, no public blob access
- **Locking**: Automatic via Azure Storage blob lease mechanism (60-second duration, auto-renewed)
- **Replication**: LRS for dev/test, GRS recommended for prod
- **Disaster Recovery**: 30-day soft delete + blob versioning

## Storage Accounts

| Environment | Resource Group | Storage Account | Container | SKU |
| --- | --- | --- | --- | --- |
| dev | `rg-tfstate-iflow-dev` | `stotfstateiflowdev` | `tfstate` | Standard_LRS |
| test | `rg-tfstate-iflow-test` | `stotfstateiflowtest` | `tfstate` | Standard_LRS |
| prod | `rg-tfstate-iflow-prod` | `stotfstateiflowprod` | `tfstate` | Standard_GRS |

**Naming Convention**: Storage accounts follow Azure CAF patterns with no hyphens (max 24 chars).

## State Files

Each integration module maintains its own state file within the environment's container:

- `int_network.tfstate` - VNet, NSG, Private DNS zones, Private Link Scope
- `int_monitoring.tfstate` - Log Analytics, Application Insights, Action Groups
- `int_common.tfstate` - Shared Managed Identity, App Service Plans
- `int_keyvault.tfstate` - Key Vault with Private Endpoints
- `int_messaging.tfstate` - Event Hub, Service Bus
- `int_storage.tfstate` - Blob, Queue, Table storage
- `int_database.tfstate` - Azure SQL
- `int_apim.tfstate` - API Management
- `int_common_functions.tfstate` - Azure Functions (.NET)
- `int_common_logic.tfstate` - Logic Apps Standard
- `int_ai.tfstate` - Cognitive Services, AI services

This modular approach allows:

- Independent deployment cycles per domain
- Parallel development across teams
- Reduced blast radius of changes
- Clear ownership boundaries

## Prerequisites

### For Local Development

1. **Azure CLI** authenticated with sufficient permissions:

   ```powershell
   az login
   az account set --subscription "<subscription-id>"
   ```

2. **RBAC Role Assignment**: Your user account needs one of:

   - `Contributor` on the tfstate resource group, OR
   - `Storage Blob Data Contributor` on the storage account/container

3. **Terraform CLI** version >= 1.9:

   ```powershell
   terraform version
   ```

4. **Storage Account Created**: The backend storage must exist before `terraform init`. See [Bootstrap Guide](#bootstrap-process) below.

### For CI/CD (GitHub Actions)

See [CI/CD Prerequisites Guide](./CICD_PREREQUISITES.md) for:

- Service principal with OIDC federation
- GitHub repository secrets configuration
- RBAC role assignments for automation

## Local Development Workflow

### 1. Initialize Module

Navigate to the module directory and initialize with backend configuration:

```powershell
cd infrastructure_as_code\environments\dev\int_network

terraform init `
  -backend-config="..\backend.conf" `
  -backend-config="key=int_network.tfstate"
```

The `backend.conf` file contains environment-specific settings (resource group, storage account, container), while the `-backend-config="key=..."` parameter specifies the unique state file for this module.

### 2. Work with State

```powershell
# View all resources in state
terraform state list

# Show details of a specific resource
terraform state show azurerm_virtual_network.this

# Pull latest state for backup
terraform state pull > state-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json

# Validate configuration
terraform validate

# Preview changes
terraform plan -var-file="terraform.tfvars"

# Apply changes
terraform apply -var-file="terraform.tfvars"
```

### 3. Common Operations

**Refresh State from Azure**:

```powershell
terraform refresh -var-file="terraform.tfvars"
```

**Import Existing Resources**:

```powershell
terraform import azurerm_resource_group.example /subscriptions/<sub-id>/resourceGroups/rg-example
```

**Move Resources Between Modules** (advanced):

```powershell
# In source module
terraform state rm azurerm_managed_identity.example

# In destination module
terraform import azurerm_managed_identity.example /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<name>
```

## Bootstrap Process

Before using Terraform remote state, you must **manually create** the Azure Storage infrastructure. This one-time setup is performed per environment.

### Step 1: Create Storage Account

Run these Azure CLI commands for each environment (dev, test, prod):

```powershell
# Variables
$ENV = "dev"  # Change to: test, prod
$RG = "rg-tfstate-iflow-$ENV"
$SA = "stotfstateiflow$ENV"
$LOCATION = "swedencentral"
$CONTAINER = "tfstate"
$SKU = "Standard_LRS"  # Use Standard_GRS for prod

# Create resource group
az group create `
  --name $RG `
  --location $LOCATION

# Create storage account
az storage account create `
  --name $SA `
  --resource-group $RG `
  --location $LOCATION `
  --sku $SKU `
  --kind StorageV2 `
  --https-only true `
  --min-tls-version TLS1_2 `
  --allow-blob-public-access false `
  --default-action Deny `
  --bypass AzureServices
```

### Step 2: Enable Versioning and Soft Delete

```powershell
# Enable blob versioning (immutable history)
az storage account blob-service-properties update `
  --account-name $SA `
  --enable-versioning true

# Enable soft delete for blobs (30-day recovery)
az storage account blob-service-properties update `
  --account-name $SA `
  --enable-delete-retention true `
  --delete-retention-days 30

# Enable soft delete for containers (30-day recovery)
az storage account blob-service-properties update `
  --account-name $SA `
  --enable-container-delete-retention true `
  --container-delete-retention-days 30
```

### Step 3: Create Container

```powershell
# Create tfstate container
az storage container create `
  --name $CONTAINER `
  --account-name $SA `
  --auth-mode login
```

### Step 4: Configure RBAC

Grant appropriate access to users and service principals:

```powershell
# Grant your user account access (for local development)
$USER_OBJECT_ID = (az ad signed-in-user show --query id -o tsv)
az role assignment create `
  --assignee $USER_OBJECT_ID `
  --role "Storage Blob Data Contributor" `
  --scope "/subscriptions/<sub-id>/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$SA/blobServices/default/containers/$CONTAINER"

# Grant GitHub Actions service principal access (for CI/CD)
# See CICD_PREREQUISITES.md for service principal creation
$SP_APP_ID = "<service-principal-app-id>"
az role assignment create `
  --assignee $SP_APP_ID `
  --role "Storage Blob Data Contributor" `
  --scope "/subscriptions/<sub-id>/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$SA/blobServices/default/containers/$CONTAINER"
```

### Step 5: Optional - Private Endpoints (Zero Trust)

If implementing full private network access (recommended for production):

```powershell
# Requires int_network module deployed first (for VNet and subnet)
$VNET_NAME = "vnet-iflow-integration-$ENV"
$SUBNET_NAME = "privateendpoint"
$PE_NAME = "pep-tfstate-iflow-$ENV"
$RG_NETWORK = "rg-iflow-network-$ENV"

# Create private endpoint
az network private-endpoint create `
  --name $PE_NAME `
  --resource-group $RG `
  --vnet-name $VNET_NAME `
  --subnet $SUBNET_NAME `
  --private-connection-resource-id "/subscriptions/<sub-id>/resourceGroups/$RG/providers/Microsoft.Storage/storageAccounts/$SA" `
  --group-id blob `
  --connection-name "pec-tfstate-$ENV" `
  --location $LOCATION

# Create private DNS zone (if not already created by int_network)
az network private-dns zone create `
  --resource-group $RG_NETWORK `
  --name "privatelink.blob.core.windows.net"

# Link private DNS zone to VNet
az network private-dns link vnet create `
  --resource-group $RG_NETWORK `
  --zone-name "privatelink.blob.core.windows.net" `
  --name "pdnslink-blob-$ENV" `
  --virtual-network $VNET_NAME `
  --registration-enabled false

# Create DNS zone group (auto-creates A record)
az network private-endpoint dns-zone-group create `
  --resource-group $RG `
  --endpoint-name $PE_NAME `
  --name "default" `
  --private-dns-zone "privatelink.blob.core.windows.net" `
  --zone-name blob
```

**Note**: With Private Endpoints enabled, local development requires either:

- VPN connection to the Azure VNet, OR
- Azure Bastion for jump host access, OR
- Temporary firewall rule for your public IP

## Backend Configuration Files

Each environment has its own `backend.conf` file:

### File: `infrastructure_as_code/environments/dev/backend.conf`

```hcl
resource_group_name  = "rg-tfstate-iflow-dev"
storage_account_name = "stotfstateiflowdev"
container_name       = "tfstate"
use_azuread_auth     = true
# key is set per-stack via: -backend-config="key=int_<module>.tfstate"
```

### File: `infrastructure_as_code/environments/test/backend.conf`

```hcl
resource_group_name  = "rg-tfstate-iflow-test"
storage_account_name = "stotfstateiflowtest"
container_name       = "tfstate"
use_azuread_auth     = true
```

### File: `infrastructure_as_code/environments/prod/backend.conf`

```hcl
resource_group_name  = "rg-tfstate-iflow-prod"
storage_account_name = "stotfstateiflowprod"
container_name       = "tfstate"
use_azuread_auth     = true
```

**Key Pattern**: The `key` parameter is always set dynamically at init time to match the module name: `int_<domain>.tfstate`.

**Authentication**: `use_azuread_auth = true` ensures RBAC-based authentication (no access keys).

## Provider Configuration

All module `providers.tf` files follow this pattern:

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
  
  backend "azurerm" {
    # Configured via CLI at initialization:
    # terraform init \
    #   -backend-config="../backend.conf" \
    #   -backend-config="key=int_<module>.tfstate"
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
  
  # CI/CD: OIDC authentication via environment variables
  # ARM_USE_OIDC=true
  # ARM_CLIENT_ID, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
}

provider "azapi" {
  subscription_id = var.subscription_id
}
```

## State Locking

Azure Storage provides automatic state locking via **blob lease mechanism**:

- **Lease Duration**: 60 seconds (auto-renewed during operations)
- **Lock Holder**: Terraform process acquires exclusive lease
- **Concurrent Protection**: Other Terraform processes wait until lease is released
- **No Additional Infrastructure**: Unlike AWS (DynamoDB required), Azure Storage handles locking natively

### Checking Lock Status

```powershell
az storage blob show `
  --account-name stotfstateiflowdev `
  --container-name tfstate `
  --name int_network.tfstate `
  --query "properties.lease" `
  --auth-mode login
```

Output:

```json
{
  "duration": "fixed",
  "state": "leased",  // or "available"
  "status": "locked"   // or "unlocked"
}
```

## Disaster Recovery

### Backup Strategy

The state backend implements **three layers of protection**:

1. **Blob Versioning** (Immutable History)
   - Every state file modification creates a new version
   - Versions are immutable and cannot be overwritten
   - Infinite retention (until manually deleted)
   - List versions: `az storage blob list --include v`

2. **Soft Delete** (30-Day Recovery Window)
   - Deleted blobs are retained for 30 days
   - Recoverable from Azure Portal or CLI
   - Applies to both blobs and containers
   - Protects against accidental deletion

3. **Geo-Redundant Replication** (Production Only)
   - **dev/test**: LRS (Locally Redundant Storage) - 3 copies within single datacenter
   - **prod**: GRS (Geo-Redundant Storage) - 6 copies across two regions (Sweden Central + paired region)
   - Automatic failover available with RA-GRS (read-access geo-redundant)

### Recovery Procedures

#### Scenario 1: Restore Previous Version (Rollback)

```powershell
# List all versions of a state file
az storage blob list `
  --account-name stotfstateiflowdev `
  --container-name tfstate `
  --prefix int_network.tfstate `
  --include v `
  --auth-mode login `
  --query "[].{name:name, versionId:versionId, isCurrentVersion:isCurrentVersion, lastModified:properties.lastModified}" `
  --output table

# Restore a specific version (becomes new current version)
az storage blob copy start `
  --source-blob "int_network.tfstate?versionId=<version-id>" `
  --destination-blob int_network.tfstate `
  --account-name stotfstateiflowdev `
  --destination-container tfstate `
  --source-account-name stotfstateiflowdev `
  --source-container tfstate `
  --auth-mode login
```

#### Scenario 2: Recover Soft-Deleted Blob

```powershell
# List soft-deleted blobs
az storage blob list `
  --account-name stotfstateiflowdev `
  --container-name tfstate `
  --include d `
  --auth-mode login

# Undelete a specific blob
az storage blob undelete `
  --account-name stotfstateiflowdev `
  --container-name tfstate `
  --name int_network.tfstate `
  --auth-mode login
```

#### Scenario 3: Complete State Loss (Export/Import)

```powershell
# Export current infrastructure state
terraform state pull > emergency-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json

# Push external state file back to remote backend
terraform state push emergency-backup-<timestamp>.json
```

**Critical**: Only use `state push` as last resort. Always prefer versioning/soft delete recovery.

#### Scenario 4: Regional Disaster (GRS Failover)

For production with GRS replication:

```powershell
# Check replication status
az storage account show `
  --name stotfstateiflowprod `
  --resource-group rg-tfstate-iflow-prod `
  --query "{status:statusOfPrimary, replication:sku.name, secondaryLocation:secondaryLocation}"

# Initiate failover to secondary region (manual approval required)
az storage account failover `
  --name stotfstateiflowprod `
  --resource-group rg-tfstate-iflow-prod `
  --yes
```

**Warning**: Failover:

- Takes 1-2 hours to complete
- Temporarily converts to LRS (must manually upgrade back to GRS)
- May result in data loss if failover initiated during active writes (RPO: ~15 minutes)

## Troubleshooting

### Problem: `Error acquiring the state lock`

**Symptoms**:

```text
Error: Error acquiring the state lock
Lock Info:
  ID:        <lock-id>
  Path:      int_network.tfstate
  Operation: OperationTypeApply
  Who:       user@machine
  Created:   2026-04-12 10:15:30 UTC
```

**Cause**: Another Terraform process is holding the lease, OR the previous process crashed without releasing the lock.

**Solution**:

1. **Wait**: Locks auto-expire after 60 seconds of inactivity
2. **Verify**: Check if another process is actually running (CI/CD job, teammate's session)
3. **Force Unlock** (only if you're certain lock is stale):

   ```powershell
   terraform force-unlock <lock-id>
   ```

**Manual Lease Break** (alternative):

```powershell
az storage blob lease break `
  --account-name stotfstateiflowdev `
  --container-name tfstate `
  --blob-name int_network.tfstate `
  --auth-mode login
```

### Problem: `Error loading state: AccessDenied`

**Symptoms**:

```text
Error: Failed to get existing workspaces: storage: service returned error:
StatusCode=403, ErrorCode=AuthorizationFailure
```

**Cause**: Missing RBAC role assignment or expired token.

**Solution**:

1. **Verify Authentication**:

   ```powershell
   az account show
   az login  # Re-authenticate if needed
   ```

2. **Check Role Assignment**:

   ```powershell
   $SCOPE = "/subscriptions/<sub-id>/resourceGroups/rg-tfstate-iflow-dev/providers/Microsoft.Storage/storageAccounts/stotfstateiflowdev"
   az role assignment list --scope $SCOPE --query "[?principalName=='<your-upn>'].roleDefinitionName"
   ```

   Expected roles: `Storage Blob Data Contributor` OR `Contributor`

3. **Grant Missing Role**:

   ```powershell
   az role assignment create `
     --assignee <your-object-id> `
     --role "Storage Blob Data Contributor" `
     --scope $SCOPE
   ```

### Problem: `Backend configuration changed`

**Symptoms**:

```text
Error: Backend configuration changed
The backend configuration has changed since initialization.
Run "terraform init -reconfigure" to update.
```

**Cause**: Storage account name, container, or other backend settings changed.

**Solution**:

```powershell
# Re-initialize with new backend config (migrates state)
terraform init -migrate-state `
  -backend-config="..\backend.conf" `
  -backend-config="key=int_network.tfstate"

# OR: Reinitialize without migrating (local state lost)
terraform init -reconfigure `
  -backend-config="..\backend.conf" `
  -backend-config="key=int_network.tfstate"
```

### Problem: `State file corrupted`

**Symptoms**:

```text
Error: state snapshot was created by Terraform vX.Y.Z, which is newer than current vA.B.C;
upgrade Terraform or use an older state snapshot
```

**Cause**: State file created with newer Terraform version, or actual corruption.

**Solution**:

1. **Check Terraform Version**:

   ```powershell
   terraform version  # Ensure >= 1.9
   ```

2. **Restore Previous Version** (see [Recovery Procedures](#recovery-procedures))

3. **Manual State Inspection**:

   ```powershell
   terraform state pull > inspect-state.json
   # Open inspect-state.json, check "terraform_version" field
   ```

## Migration Guide

### Migrating Existing Module from Local to Remote State

For the `int_network` module (already deployed with local state):

#### Step 1: Backup Local State

```powershell
cd infrastructure_as_code\environments\dev\int_network
terraform state pull > local-state-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').json
```

#### Step 2: Add Backend Configuration

Ensure `providers.tf` includes backend block:

```hcl
backend "azurerm" {
  # Configured at init time
}
```

#### Step 3: Initialize with Backend

```powershell
terraform init -migrate-state `
  -backend-config="..\backend.conf" `
  -backend-config="key=int_network.tfstate"
```

Terraform will prompt:

```text
Do you want to migrate all workspaces to "azurerm"?
  Enter a value: yes
```

#### Step 4: Verify Migration

```powershell
# Local state should be removed
if (Test-Path "terraform.tfstate") {
  Write-Warning "Local state still exists! Check migration."
}

# Remote state should exist
az storage blob list `
  --account-name stotfstateiflowdev `
  --container-name tfstate `
  --prefix int_network.tfstate `
  --auth-mode login

# Verify Terraform can read state
terraform state list
```

#### Step 5: Test Operations

```powershell
# Should show no changes (state matches infrastructure)
terraform plan -var-file="terraform.tfvars"
```

## CI/CD Integration

For GitHub Actions configuration, see:

- **[CI/CD Prerequisites Guide](./CICD_PREREQUISITES.md)** - Complete setup instructions
- **[GitHub Actions Workflow](./.github/workflows/terraform-apply.yml)** - Example workflow file

## Security Best Practices

✅ **Implemented**:

- RBAC-based authentication (no storage account keys)
- HTTPS-only with TLS 1.2+ enforcement
- No public blob access (`--allow-blob-public-access false`)
- Blob versioning for audit trail
- 30-day soft delete for recovery
- Storage account firewall rules (`--default-action Deny`)

🔒 **Optional Enhancements**:

- **Private Endpoints**: Zero Trust network access (recommended for production)
- **Customer-Managed Keys**: Azure Key Vault encryption keys (compliance requirement?)
- **Immutable Blobs**: Time-based retention policies (legal/audit requirement?)
- **Diagnostic Logs**: Send storage logs to Log Analytics (operational monitoring)

## Reference Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                   GitHub Actions Workflow                    │
│                  (OIDC Authentication)                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     │ terraform init/plan/apply
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Azure Storage (State Backend)                   │
│  ┌──────────────┬──────────────┬───────────────┐            │
│  │ dev storage  │ test storage │ prod storage  │            │
│  │ stotfstate…  │ stotfstate…  │ stotfstate…   │            │
│  │              │              │               │            │
│  │ /tfstate/    │ /tfstate/    │ /tfstate/     │            │
│  │  - int_*.tf… │  - int_*.tf… │  - int_*.tf…  │            │
│  └──────────────┴──────────────┴───────────────┘            │
│      (LRS)          (LRS)           (GRS)                    │
└─────────────────────────────────────────────────────────────┘
                     │
                     │ terraform manages
                     ▼
┌─────────────────────────────────────────────────────────────┐
│               Azure Infrastructure (iFlow)                   │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ int_network: VNet, NSG, Private DNS, Private Link   │    │
│  │ int_monitoring: Log Analytics, App Insights         │    │
│  │ int_common: Managed Identity, App Service Plans     │    │
│  │ int_keyvault: Key Vault (with Private Endpoints)    │    │
│  │ ... (8 more modules)                                │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Additional Resources

- **Azure Storage Best Practices**: <https://learn.microsoft.com/azure/storage/common/storage-best-practices>
- **Terraform Backend Configuration**: <https://developer.hashicorp.com/terraform/language/settings/backends/azurerm>
- **Zero Trust Architecture**: <https://learn.microsoft.com/security/zero-trust/>
- **iFlow Project Documentation**: See `/docs/ARCHITECTURE.md` (Swedish)

---

**Document Version**: 1.0  
**Last Updated**: April 12, 2026  
**Maintainer**: iFlow Platform Team
