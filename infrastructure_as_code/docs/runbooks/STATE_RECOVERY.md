# Terraform State Recovery Runbook

## Overview

This operational runbook provides step-by-step procedures for recovering from Terraform state file issues in the iFlow integration platform. Use this guide for disaster recovery, state corruption, accidental deletions, and state lock problems.

**Audience**: DevOps engineers, platform operators, incident responders

**Prerequisites**:

- Azure CLI authenticated with appropriate RBAC permissions
- Terraform CLI installed (version >= 1.9)
- Access to Azure Portal (for manual verification)
- Understanding of Terraform state concepts

## Quick Reference

| Scenario | Severity | Recovery Time | Data Loss Risk |
| --- | --- | --- | --- |
| [Locked State](#scenario-1-locked-state-file) | 🟡 Low | 1-5 minutes | None |
| [Accidental Deletion](#scenario-2-accidental-deletion) | 🟠 Medium | 5-10 minutes | None (with soft delete) |
| [State Corruption](#scenario-3-state-corruption) | 🔴 High | 10-30 minutes | Minimal (with versioning) |
| [Regional Disaster](#scenario-4-regional-disaster-prod-only) | 🔴 Critical | 1-2 hours | ~15 minutes RPO |
| [Manual Drift Reconciliation](#scenario-5-manual-drift-reconciliation) | 🟡 Low | 15-60 minutes | None |

## Scenario 1: Locked State File

### Symptoms

```text
Error: Error acquiring the state lock

Lock Info:
  ID:        1234567890abcdef-1234567890abcdef
  Path:      int_network.tfstate
  Operation: OperationTypeApply
  Who:       user@machine
  Created:   2026-04-12 10:15:30 UTC

Terraform process tried to acquire the lock but failed.
```

### Cause

- Another Terraform process is actively using the state (CI/CD job, teammate's session)
- Previous process crashed or was terminated without releasing the lock
- Network interruption during state operation

### Investigation Steps

#### Step 1: Verify Lock Holder

Check if another process is legitimately running:

```powershell
# Check GitHub Actions workflows
gh run list --repo kjfisk-cplt/iflow --limit 5

# Ask team members
# "Is anyone running terraform apply/plan for [module]?"
```

#### Step 2: Check Lock Age

```powershell
$ENV = "dev"  # or test, prod
$MODULE = "int_network"
$SA = "stotfstateiflow$ENV"

az storage blob show `
  --account-name $SA `
  --container-name tfstate `
  --name "$MODULE.tfstate" `
  --auth-mode login `
  --query "properties.lease" `
  --output json
```

Output example:

```json
{
  "duration": "infinite",
  "state": "leased",
  "status": "locked"
}
```

### Resolution

#### Option A: Wait (Recommended)

Locks **auto-expire after 60 seconds** of inactivity. Wait and retry:

```powershell
Start-Sleep -Seconds 65
terraform plan -var-file="terraform.tfvars"
```

#### Option B: Force Unlock (If Lock is Stale)

⚠️ **Only use if you're certain no other process is running.**

```powershell
# Unlock using Terraform
terraform force-unlock <LOCK_ID>

# Example:
terraform force-unlock 1234567890abcdef-1234567890abcdef
```

Terraform will prompt for confirmation:

```text
Do you really want to force-unlock?
  Type 'yes' to confirm: yes
```

#### Option C: Break Lease Manually (Last Resort)

⚠️ **Use only if `terraform force-unlock` fails.**

```powershell
az storage blob lease break `
  --account-name $SA `
  --container-name tfstate `
  --blob-name "$MODULE.tfstate" `
  --auth-mode login `
  --lease-break-period 0  # Immediate break
```

### Validation

```powershell
# Verify lock released
az storage blob show `
  --account-name $SA `
  --container-name tfstate `
  --name "$MODULE.tfstate" `
  --query "properties.lease.status" `
  --output tsv
# Expected: "unlocked"

# Test Terraform can acquire lock
terraform plan -var-file="terraform.tfvars"
```

### Prevention

- Ensure proper workflow cancellation in GitHub Actions (cancel running jobs before re-triggering)
- Use Terraform timeouts: `terraform apply -lock-timeout=5m`
- Implement workflow concurrency limits in GitHub Actions:

  ```yaml
  concurrency:
    group: terraform-${{ matrix.module }}
    cancel-in-progress: true
  ```

---

## Scenario 2: Accidental Deletion

### Symptoms (Accidental Deletion)

```text
Error: Failed to get existing workspaces: storage: service returned error:
StatusCode=404, ErrorCode=BlobNotFound, RequestId=<uuid>
```

Or user reports: "State file disappeared after I deleted it by mistake."

### Cause (Accidental Deletion)

- Manual deletion via Azure Portal, Azure CLI, or Storage Explorer
- Script or automation error
- Misconfigured retention policies

### Investigation Steps (Accidental Deletion)

#### Step 1: Confirm Deletion

```powershell
# Check if blob exists
az storage blob exists `
  --account-name $SA `
  --container-name tfstate `
  --name "$MODULE.tfstate" `
  --auth-mode login `
  --query "exists" `
  --output tsv
# Output: "false"
```

#### Step 2: Check Soft Delete Status

```powershell
# List soft-deleted blobs
az storage blob list `
  --account-name $SA `
  --container-name tfstate `
  --include d `
  --auth-mode login `
  --query "[?deleted].{name:name, deletedTime:properties.deletedTime, remainingRetentionDays:properties.remainingRetentionDays}" `
  --output table
```

Output:

```text
Name                    DeletedTime                      RemainingRetentionDays
----------------------  -------------------------------  ----------------------
int_network.tfstate     2026-04-12T10:30:00.000000+00:00  29
```

### Resolution (Accidental Deletion)

#### Step 1: Undelete Soft-Deleted Blob

```powershell
az storage blob undelete `
  --account-name $SA `
  --container-name tfstate `
  --name "$MODULE.tfstate" `
  --auth-mode login
```

Output:

```text
Successfully undeleted blob: int_network.tfstate
```

#### Step 2: Verify Recovery

```powershell
# Check blob exists
az storage blob exists `
  --account-name $SA `
  --container-name tfstate `
  --name "$MODULE.tfstate" `
  --query "exists" `
  --output tsv
# Expected: "true"

# Test Terraform can read state
terraform state list
```

### If Soft Delete Period Expired

If soft delete retention expired (>30 days), restore from version history:

```powershell
# List all versions (including from before deletion)
az storage blob list `
  --account-name $SA `
  --container-name tfstate `
  --prefix "$MODULE.tfstate" `
  --include v `
  --auth-mode login `
  --query "[-5:].{name:name, versionId:versionId, lastModified:properties.lastModified, isCurrentVersion:isCurrentVersion}" `
  --output table

# Copy specific version to current blob
az storage blob copy start `
  --source-blob "$MODULE.tfstate?versionId=<version-id>" `
  --destination-blob "$MODULE.tfstate" `
  --account-name $SA `
  --destination-container tfstate `
  --source-account-name $SA `
  --source-container tfstate `
  --auth-mode login
```

### Prevention (Accidental Deletion)

- Enable soft delete with sufficient retention (current: 30 days)
- Implement RBAC least privilege (prevent accidental deletions)
- Add resource locks on state storage accounts:

  ```powershell
  az lock create `
    --name "DoNotDelete-TfState" `
    --resource-group $RG `
    --resource-type "Microsoft.Storage/storageAccounts" `
    --resource-name $SA `
    --lock-type CanNotDelete
  ```

---

## Scenario 3: State Corruption

### Symptoms (State Corruption)

```text
Error: state snapshot was created by Terraform v1.10.0, which is newer than current v1.9.0;
upgrade Terraform or use an older state snapshot
```

Or:

```text
Error: Failed to decode state: EOF
```

Or:

```text
Error: state file has been tampered with; checksum mismatch
```

### Cause (State Corruption)

- State file edited manually (never do this!)
- Terraform version mismatch across team/CI
- Concurrent writes bypassing state lock
- Storage corruption (rare)

### Investigation Steps (State Corruption)

#### Step 1: Pull and Inspect State

```powershell
# Download current state
terraform state pull > corrupted-state.json

# Check if valid JSON
Get-Content corrupted-state.json -ErrorAction Stop
# If error: File is corrupted binary or truncated

# Check Terraform version in state
(Get-Content corrupted-state.json | ConvertFrom-Json).terraform_version
```

#### Step 2: List Available Versions

```powershell
az storage blob list `
  --account-name $SA `
  --container-name tfstate `
  --prefix "$MODULE.tfstate" `
  --include v `
  --auth-mode login `
  --query "[].{versionId:versionId, lastModified:properties.lastModified, size:properties.contentLength}" `
  --output table | Sort-Object -Property lastModified -Descending
```

### Resolution (State Corruption)

#### Step 1: Identify Last Good Version

```powershell
# Download specific versions for inspection
$VERSIONS = @("version-id-1", "version-id-2", "version-id-3")

foreach ($VERSION in $VERSIONS) {
    az storage blob download `
      --account-name $SA `
      --container-name tfstate `
      --name "$MODULE.tfstate" `
      --version-id $VERSION `
      --file "state-$VERSION.json" `
      --auth-mode login
    
    # Test validity
    try {
        $STATE = Get-Content "state-$VERSION.json" | ConvertFrom-Json
        Write-Host "✓ Version $VERSION is valid (Terraform $($STATE.terraform_version))" -ForegroundColor Green
    } catch {
        Write-Host "✗ Version $VERSION is corrupted" -ForegroundColor Red
    }
}
```

#### Step 2: Restore Last Good Version

```powershell
# Copy good version to current blob
$GOOD_VERSION = "<version-id>"
az storage blob copy start `
  --source-blob "$MODULE.tfstate?versionId=$GOOD_VERSION" `
  --destination-blob "$MODULE.tfstate" `
  --account-name $SA `
  --destination-container tfstate `
  --source-account-name $SA `
  --source-container tfstate `
  --auth-mode login

# Wait for copy to complete
az storage blob show `
  --account-name $SA `
  --container-name tfstate `
  --name "$MODULE.tfstate" `
  --query "properties.copy.status" `
  --output tsv
# Expected: "success"
```

#### Step 3: Verify and Reconcile

```powershell
# Initialize Terraform
terraform init `
  -backend-config="..\backend.conf" `
  -backend-config="key=$MODULE.tfstate"

# Check state
terraform state list

# Compare with actual infrastructure
terraform plan -var-file="terraform.tfvars"
```

**If drift detected** (state older than current infrastructure):

```powershell
# Refresh state from Azure
terraform apply -refresh-only -var-file="terraform.tfvars"

# Or manually import missing resources
terraform import <address> <azure-resource-id>
```

### Prevention (State Corruption)

- Never manually edit state files
- Enforce Terraform version constraints:

  ```hcl
  terraform {
    required_version = ">= 1.9, < 2.0"
  }
  ```

- Use `.terraform-version` file in repository root
- Regular state backups:

  ```powershell
  # Automated backup script (run daily)
  terraform state pull > "backups\state-$(Get-Date -Format 'yyyyMMdd').json"
  ```

---

## Scenario 4: Regional Disaster (Prod Only)

### Symptoms (Regional Disaster)

- Azure region outage (Sweden Central unavailable)
- Storage account inaccessible (HTTP 503 errors)
- All Terraform operations timing out

### Cause (Regional Disaster)

- Azure datacenter outage
- Network partition
- Service degradation

### Investigation Steps (Regional Disaster)

#### Step 1: Check Azure Service Health

```powershell
# Check service health
az monitor service-health list --query "[?name=='Storage']" --output table

# Check specific storage account status
az storage account show `
  --name stotfstateiflowprod `
  --resource-group rg-tfstate-iflow-prod `
  --query "{statusOfPrimary:statusOfPrimary, statusOfSecondary:statusOfSecondary}" `
  --output json
```

#### Step 2: Verify GRS Replication

```powershell
az storage account show `
  --name stotfstateiflowprod `
  --query "{sku:sku.name, primary:primaryLocation, secondary:secondaryLocation}" `
  --output json
```

Expected output (production):

```json
{
  "sku": "Standard_GRS",
  "primary": "swedencentral",
  "secondary": "swenorcentral"  # Paired region
}
```

### Resolution (Regional Disaster)

#### Option A: Wait for Primary Region Recovery (Recommended)

If outage is expected to be brief (<4 hours):

1. Monitor Azure Status: <https://status.azure.com>
2. Postpone deployments until primary region recovers
3. No action required (GRS replication ensures data safety)

#### Option B: Initiate Failover to Secondary Region

⚠️ **Critical Decision** - Requires approval from Platform Lead

**Trade-offs**:

- **RPO**: ~15 minutes potential data loss
- **Downtime**: 1-2 hours failover duration
- **Post-failover**: Account converts to LRS (must manually upgrade back to GRS)

**Procedure**:

```powershell
# Step 1: Verify secondary endpoint is accessible
$SECONDARY_ENDPOINT = "https://stotfstateiflowprod-secondary.blob.core.windows.net"
Invoke-WebRequest -Uri "$SECONDARY_ENDPOINT/tfstate?restype=container&comp=list" -Method GET

# Step 2: Initiate failover
az storage account failover `
  --name stotfstateiflowprod `
  --resource-group rg-tfstate-iflow-prod `
  --yes

# Step 3: Monitor failover progress (1-2 hours)
while ($true) {
    $STATUS = az storage account show `
      --name stotfstateiflowprod `
      --query "statusOfPrimary" `
      --output tsv
    
    Write-Host "Failover status: $STATUS ($(Get-Date -Format 'HH:mm:ss'))"
    
    if ($STATUS -eq "available") {
        Write-Host "✓ Failover complete" -ForegroundColor Green
        break
    }
    
    Start-Sleep -Seconds 60
}

# Step 4: Update infrastructure after failover
# New primary location is now the old secondary (Sweden North)

# Step 5: Upgrade back to GRS (after primary region recovers)
az storage account update `
  --name stotfstateiflowprod `
  --resource-group rg-tfstate-iflow-prod `
  --sku Standard_GRS
```

#### Option C: Restore from Local Backup (If Failover Not Possible)

Last resort if both regions are unavailable:

```powershell
# Find latest local backup
$LATEST_BACKUP = Get-ChildItem -Path "backups\" -Filter "state-*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

# Push backup to new temporary storage location
# (Requires manual creation of new storage account in available region)

terraform state push $LATEST_BACKUP.FullName
```

### Post-Recovery Actions

1. **Verify State Integrity**:

   ```powershell
   terraform state list
   terraform plan -var-file="terraform.tfvars"  # Should show no changes
   ```

2. **Document Incident**:
   - RPO/RTO achieved
   - Data loss (if any)
   - Decisions made during incident

3. **Review and Improve**:
   - Consider GZRS (geo-zone-redundant) for higher availability
   - Implement automated health checks
   - Practice failover procedures annually

---

## Scenario 5: Manual Drift Reconciliation

### Symptoms (Manual Drift Reconciliation)

```text
Terraform plan shows resources that no longer exist in Azure,
or resources exist in Azure but not in state.
```

Or:

```text
Error: Error building account: <resource> not found
```

### Cause (Manual Drift Reconciliation)

- Manual changes in Azure Portal (bypassing Terraform)
- Resources deleted outside Terraform
- Partial deployment failures
- State out of sync with reality

### Investigation Steps (Manual Drift Reconciliation)

#### Step 1: Identify Drift

```powershell
# Run plan to see drift
terraform plan -var-file="terraform.tfvars"

# Example output:
# + azurerm_resource_group.example  # Should exist but doesn't in state
# - azurerm_storage_account.example # In state but doesn't exist in Azure
```

#### Step 2: Verify in Azure

```powershell
# Check specific resource
az resource show --ids "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>"

# Or list all resources in resource group
az resource list --resource-group rg-iflow-network-dev --output table
```

### Resolution (Manual Drift Reconciliation)

#### Case A: Resource Exists in Azure, Missing from State

**Import the resource**:

```powershell
# Syntax: terraform import <terraform_address> <azure_resource_id>

# Example: Import virtual network
terraform import azurerm_virtual_network.this "/subscriptions/<sub-id>/resourceGroups/rg-iflow-network-dev/providers/Microsoft.Network/virtualNetworks/vnet-iflow-integration-dev"

# Verify import
terraform state show azurerm_virtual_network.this
```

#### Case B: Resource in State, Doesn't Exist in Azure

**Remove from state**:

```powershell
# Syntax: terraform state rm <address>

# Example: Remove deleted storage account
terraform state rm azurerm_storage_account.example

# Verify removal
terraform state list | Select-String "storage_account"
```

**Then recreate** (if resource should exist):

```powershell
terraform apply -var-file="terraform.tfvars"
```

#### Case C: Configuration Drift (Resource exists but attributes differ)

**Revert manual changes**:

```powershell
# Terraform will detect drift and propose correction
terraform plan -var-file="terraform.tfvars"

# Apply to revert to Terraform-managed configuration
terraform apply -var-file="terraform.tfvars"
```

**Or update Terraform to match reality** (if manual change is desired):

1. Edit `.tf` files to match Azure configuration
2. Run `terraform plan` to verify no changes needed

### Prevention (Manual Drift Reconciliation)

- Implement Azure Policy to prevent manual changes in Terraform-managed resources
- Add resource tags: `managed_by = "terraform"`
- Enable diagnostic logs for audit trail:

  ```powershell
  az monitor diagnostic-settings create `
    --name "audit-logs" `
    --resource "/subscriptions/<sub>/resourceGroups/<rg>" `
    --workspace "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/<workspace>" `
    --logs '[{"category": "Administrative", "enabled": true}]'
  ```

---

## Emergency Contacts

| Role | Contact | Availability |
| --- | --- | --- |
| Platform Lead | <platform-lead@iflow.se> | 24/7 (on-call) |
| DevOps Engineer (Primary) | <devops@iflow.se> | Business hours |
| Azure Support | Azure Portal → Support | 24/7 (Severity A) |

## Escalation Path

1. **Level 1** (0-15 min): DevOps engineer attempts recovery following this runbook
2. **Level 2** (15-30 min): Platform Lead involved, considers failover options
3. **Level 3** (30-60 min): Azure Support engaged (open Severity A ticket)
4. **Level 4** (>60 min): Executive notification, business continuity plan activation

## Post-Incident Actions

After any state recovery incident:

1. **Update Runbook**: Document any new issues or solutions
2. **Root Cause Analysis**: Determine how issue occurred
3. **Preventive Measures**: Implement controls to prevent recurrence
4. **Team Training**: Share learnings with team
5. **Test Recovery**: Schedule regular DR drills (quarterly)

---

**Document Version**: 1.0  
**Last Updated**: April 12, 2026  
**Maintainer**: iFlow Platform Team  
**Review Schedule**: Quarterly
