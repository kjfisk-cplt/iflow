# Terraform Infrastructure Scripts

PowerShell automation scripts for bootstrapping and configuring Terraform remote state infrastructure for the IFlow integration platform.

---

## Scripts Overview

| Script | Purpose | Prerequisites |
| --- | --- | --- |
| [`bootstrap-state-storage.ps1`](bootstrap-state-storage.ps1) | Create Azure Storage backend for Terraform state | Azure CLI + Contributor access |
| [`configure-oidc.ps1`](configure-oidc.ps1) | Configure service principal with OIDC for GitHub Actions | Azure CLI + Application Administrator role |

---

## bootstrap-state-storage.ps1

Creates the Azure infrastructure required for Terraform remote state management:

- Resource Group
- Storage Account with versioning and soft delete
- Blob container
- RBAC role assignments

### Usage (bootstrap-state-storage) (bootstrap-state-storage)

**Dev environment:**

```powershell
.\bootstrap-state-storage.ps1 `
  -Environment dev `
  -SubscriptionId "12345678-1234-1234-1234-123456789012"
```

**Prod environment with service principal:**

```powershell
.\bootstrap-state-storage.ps1 `
  -Environment prod `
  -SubscriptionId "12345678-1234-1234-1234-123456789012" `
  -ServicePrincipalId "abcd1234-5678-90ab-cdef-1234567890ab"
```

**Preview changes without creating resources:**

```powershell
.\bootstrap-state-storage.ps1 `
  -Environment test `
  -SubscriptionId "12345678-1234-1234-1234-123456789012" `
  -WhatIf
```

### Parameters (bootstrap-state-storage)

| Parameter | Required | Default | Description |
| --- | --- | --- | --- |
| `Environment` | Yes | - | Target environment: `dev`, `test`, or `prod` |
| `SubscriptionId` | Yes | - | Azure subscription ID (GUID format) |
| `Location` | No | `swedencentral` | Azure region for resources |
| `Workload` | No | `iflow` | Workload identifier in naming |
| `AssignRbac` | No | `$true` | Assign Storage Blob Data Contributor to current user |
| `ServicePrincipalId` | No | - | Service principal Object ID for RBAC (CI/CD) |
| `WhatIf` | No | `$false` | Preview changes without creating resources |

### Output (bootstrap-state-storage)

The script creates:

- **Resource Group:** `rg-tfstate-iflow-{env}`
- **Storage Account:** `stotfstateiflow{env}` (24 char limit)
- **Container:** `tfstate`
- **SKU:** `Standard_LRS` (dev/test), `Standard_GRS` (prod)
- **Features:** Blob versioning (infinite retention), soft delete (30 days)

---

## configure-oidc.ps1

Configures Azure service principal with OIDC federated credentials for keyless authentication from GitHub Actions to Azure.

### Usage (configure-oidc)

**Standard setup:**

```powershell
.\configure-oidc.ps1 `
  -SubscriptionId "12345678-1234-1234-1234-123456789012" `
  -GitHubOrg "kjfisk-cplt" `
  -GitHubRepo "iflow"
```

**Custom service principal name:**

```powershell
.\configure-oidc.ps1 `
  -SubscriptionId "12345678-1234-1234-1234-123456789012" `
  -GitHubOrg "kjfisk-cplt" `
  -GitHubRepo "iflow" `
  -ServicePrincipalName "sp-gh-actions-custom"
```

**Preview configuration:**

```powershell
.\configure-oidc.ps1 `
  -SubscriptionId "12345678-1234-1234-1234-123456789012" `
  -GitHubOrg "kjfisk-cplt" `
  -GitHubRepo "iflow" `
  -WhatIf
```

### Parameters (configure-oidc)

| Parameter | Required | Default | Description |
| --- | --- | --- | --- |
| `SubscriptionId` | Yes | - | Azure subscription ID (GUID format) |
| `GitHubOrg` | Yes | - | GitHub organization name (e.g., `kjfisk-cplt`) |
| `GitHubRepo` | Yes | - | GitHub repository name (e.g., `iflow`) |
| `ServicePrincipalName` | No | `gh-actions-iflow` | Name for the service principal |
| `StateStorageResourceGroups` | No | `rg-tfstate-iflow-dev,rg-tfstate-iflow-test,rg-tfstate-iflow-prod` | Comma-separated list of state storage RGs |

### Output (configure-oidc)

The script configures:

- **Service Principal:** `gh-actions-iflow` (or custom name)
- **Federated Credentials (5):**
  - Main branch deployments (`ref:refs/heads/main`)
  - Pull request validation (`pull_request`)
  - Environment-specific: `dev`, `test`, `prod`
- **RBAC Roles:**
  - `Contributor` (subscription scope)
  - `Storage Blob Data Contributor` (state storage accounts)

Displays required GitHub Secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

---

## Workflow

### Initial Setup (One-time)

1. **Bootstrap all environments:**

   ```powershell
   # Dev
   .\bootstrap-state-storage.ps1 -Environment dev -SubscriptionId "..."
   
   # Test
   .\bootstrap-state-storage.ps1 -Environment test -SubscriptionId "..."
   
   # Prod
   .\bootstrap-state-storage.ps1 -Environment prod -SubscriptionId "..."
   ```

2. **Configure OIDC for GitHub Actions:**

   ```powershell
   .\configure-oidc.ps1 -SubscriptionId "..." -GitHubOrg "kjfisk-cplt" -GitHubRepo "iflow"
   ```

3. **Add secrets to GitHub:**

   - Navigate to: `https://github.com/{org}/{repo}/settings/secrets/actions`
   - Add the three secrets displayed by the script

4. **Configure GitHub Environments:**

   - Settings → Environments → Create: `dev`, `test`, `prod`
   - Add protection rules for `prod` (required reviewers, main branch only)

### Verification

Test the setup:

```powershell
# Verify storage account configuration
az storage account show `
  --name stotfstateiflowdev `
  --query "{Name:name, Sku:sku.name, Versioning:blobRestorePolicy.enabled}"

# Verify RBAC assignments
az role assignment list `
  --assignee <service-principal-app-id> `
  --scope "/subscriptions/<subscription-id>"

# Test Terraform init
cd ../environments/dev/int_network
terraform init `
  -backend-config="../backend.conf" `
  -backend-config="key=int_network.tfstate"
```

---

## Prerequisites

### Required Software

- **Azure CLI >= 2.50.0**

  ```powershell
  winget install Microsoft.AzureCLI
  ```

- **PowerShell >= 7.0** (Windows PowerShell 5.1 also supported)

### Required Permissions

- **For bootstrap-state-storage.ps1:**

  - `Contributor` role at subscription scope (to create resource groups and storage accounts)
  - Alternatively: `Owner` role on specific resource groups

- **For configure-oidc.ps1:**

  - `Application Administrator` role in Microsoft Entra ID (to create service principals)
  - `User Access Administrator` or `Owner` at subscription scope (for RBAC assignments)

### Azure CLI Authentication

Authenticate before running scripts:

```powershell
# Interactive login
az login

# Set subscription context
az account set --subscription <subscription-id>

# Verify
az account show
```

---

## Troubleshooting

### Error: "Failed to authorize with Azure CLI"

**Cause:** Not logged in or insufficient permissions.

**Solution:**

```powershell
az logout
az login
az account set --subscription <subscription-id>
```

### Error: "Storage account name already exists"

**Cause:** Storage account names are globally unique across Azure.

**Solution:**

- Verify the account belongs to your subscription:

  ```powershell
  az storage account show --name stotfstateiflowdev
  ```

- If it belongs to another subscription, change the `Workload` parameter:

  ```powershell
  .\bootstrap-state-storage.ps1 -Environment dev -SubscriptionId "..." -Workload "iflow2"
  ```

### Error: "Insufficient privileges to complete the operation"

**Cause:** Missing Application Administrator role for OIDC configuration.

**Solution:**
Request role from Global Administrator or use Privileged Identity Management (PIM) to elevate.

### Warning: "Role assignment may already exist"

**Behavior:** Azure CLI returns non-zero exit code when role assignment already exists.

**Impact:** Script handles this gracefully with warnings. Safe to ignore.

---

## Additional Resources

- **Terraform State Setup Guide:** [../docs/TERRAFORM_STATE_SETUP.md](../docs/TERRAFORM_STATE_SETUP.md)
- **CI/CD Prerequisites:** [../docs/CICD_PREREQUISITES.md](../docs/CICD_PREREQUISITES.md)
- **State Recovery Runbook:** [../docs/runbooks/STATE_RECOVERY.md](../docs/runbooks/STATE_RECOVERY.md)
- **Architecture Documentation:** [../../docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md)

---

**Script Versions:** 1.0  
**Last Updated:** 2024-05-15  
**Maintained by:** IFlow Platform Team
