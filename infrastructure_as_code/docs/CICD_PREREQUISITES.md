# CI/CD Prerequisites for GitHub Actions

## Overview

This document outlines the prerequisites and configuration steps required to deploy iFlow infrastructure via GitHub Actions using Terraform. The setup uses **OIDC (OpenID Connect) federation** for secure, keyless authentication between GitHub and Azure—eliminating the need to store long-lived secrets.

## Prerequisites Checklist

Before deploying infrastructure via GitHub Actions, complete these steps:

- [ ] **Azure**: State storage accounts created for all environments (dev, test, prod)
- [ ] **Azure**: Service principal with OIDC federation configured
- [ ] **Azure**: RBAC role assignments granted to service principal
- [ ] **GitHub**: Repository secrets configured (Client ID, Tenant ID, Subscription ID)
- [ ] **GitHub**: GitHub Actions workflows created and tested
- [ ] **GitHub**: Branch protection rules enabled (recommended for prod)

## Architecture Overview

```text
GitHub Actions Workflow (Pull Request or Push)
    │
    ├─ 1. Request OIDC Token from GitHub
    │     (Subject: repo:kjfisk-cplt/iflow:ref:refs/heads/main)
    │
    ├─ 2. Exchange Token with Azure AD
    │     (Federated credential validates issuer & subject)
    │
    ├─ 3. Receive Azure Access Token
    │     (Short-lived, automatically rotates)
    │
    ├─ 4. Authenticate to Azure
    │     (terraform init, plan, apply)
    │
    ├─ 5. Access State Backend
    │     (Storage Blob Data Contributor role)
    │
    └─ 6. Deploy Infrastructure
          (Contributor role on subscription)
```

**Benefits of OIDC**:

- ✅ No secrets stored in GitHub (keyless authentication)
- ✅ Automatic token rotation (short-lived tokens)
- ✅ Granular control (repo, branch, environment specificity)
- ✅ Reduced attack surface (no client secrets to leak)

## Part 1: Azure Setup

### Step 1.1: Create Service Principal

Create an Azure AD application registration and service principal:

```powershell
# Create application registration
$APP_DISPLAY_NAME = "github-actions-iflow"
$APP = az ad app create --display-name $APP_DISPLAY_NAME | ConvertFrom-Json
$APP_ID = $APP.appId

Write-Host "✓ App Registration created: $APP_ID" -ForegroundColor Green

# Create service principal from app
az ad sp create --id $APP_ID

Write-Host "✓ Service Principal created" -ForegroundColor Green
```

**Save the `$APP_ID`** - you'll need it for:

- OIDC federated credentials (next step)
- RBAC role assignments (step 1.3)
- GitHub secrets (step 2.1)

### Step 1.2: Configure OIDC Federation

Add federated credentials to establish trust between GitHub and Azure:

#### Credential 1: Main Branch Deployments

```powershell
az ad app federated-credential create `
  --id $APP_ID `
  --parameters @"
{
  "name": "github-actions-iflow-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:kjfisk-cplt/iflow:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"],
  "description": "Deploy from main branch"
}
"@

Write-Host "✓ Federated credential created for main branch" -ForegroundColor Green
```

#### Credential 2: Pull Request (Plan Only)

```powershell
az ad app federated-credential create `
  --id $APP_ID `
  --parameters @"
{
  "name": "github-actions-iflow-pull-request",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:kjfisk-cplt/iflow:pull_request",
  "audiences": ["api://AzureADTokenExchange"],
  "description": "Terraform plan for pull requests"
}
"@

Write-Host "✓ Federated credential created for pull requests" -ForegroundColor Green
```

#### Credential 3: Environment-Specific (Optional)

For environment protection rules in GitHub:

```powershell
# Example: Production environment
az ad app federated-credential create `
  --id $APP_ID `
  --parameters @"
{
  "name": "github-actions-iflow-production",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:kjfisk-cplt/iflow:environment:production",
  "audiences": ["api://AzureADTokenExchange"],
  "description": "Deploy to production environment"
}
"@
```

**Verification**:

```powershell
az ad app federated-credential list --id $APP_ID --query "[].{name:name, subject:subject}" -o table
```

### Step 1.3: Assign RBAC Roles

Grant the service principal permissions to deploy infrastructure and access state storage.

#### Role 1: Contributor (Infrastructure Deployment)

```powershell
$SUBSCRIPTION_ID = (az account show --query id -o tsv)

az role assignment create `
  --assignee $APP_ID `
  --role "Contributor" `
  --scope "/subscriptions/$SUBSCRIPTION_ID" `
  --description "Deploy iFlow infrastructure resources"

Write-Host "✓ Contributor role assigned at subscription scope" -ForegroundColor Green
```

**Alternative**: For tighter security, assign Contributor only to specific resource groups instead of subscription-wide.

#### Role 2: Storage Blob Data Contributor (State Backend Access)

Grant access to each environment's state storage:

```powershell
# Dev environment
az role assignment create `
  --assignee $APP_ID `
  --role "Storage Blob Data Contributor" `
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-tfstate-iflow-dev/providers/Microsoft.Storage/storageAccounts/stotfstateiflowdev/blobServices/default/containers/tfstate" `
  --description "Access dev state backend"

# Test environment
az role assignment create `
  --assignee $APP_ID `
  --role "Storage Blob Data Contributor" `
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-tfstate-iflow-test/providers/Microsoft.Storage/storageAccounts/stotfstateiflowtest/blobServices/default/containers/tfstate" `
  --description "Access test state backend"

# Prod environment
az role assignment create `
  --assignee $APP_ID `
  --role "Storage Blob Data Contributor" `
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/rg-tfstate-iflow-prod/providers/Microsoft.Storage/storageAccounts/stotfstateiflowprod/blobServices/default/containers/tfstate" `
  --description "Access prod state backend"

Write-Host "✓ Storage Blob Data Contributor roles assigned for all environments" -ForegroundColor Green
```

**Verification**:

```powershell
az role assignment list --assignee $APP_ID --query "[].{role:roleDefinitionName, scope:scope}" -o table
```

Expected output:

```text
Role                            Scope
------------------------------  ---------------------------------------------------------------
Contributor                     /subscriptions/<sub-id>
Storage Blob Data Contributor   /subscriptions/<sub-id>/resourceGroups/rg-tfstate-iflow-dev/...
Storage Blob Data Contributor   /subscriptions/<sub-id>/resourceGroups/rg-tfstate-iflow-test/...
Storage Blob Data Contributor   /subscriptions/<sub-id>/resourceGroups/rg-tfstate-iflow-prod/...
```

### Step 1.4: Collect Azure Credentials

Gather the following values for GitHub secrets configuration:

```powershell
# Subscription ID
$SUBSCRIPTION_ID = (az account show --query id -o tsv)

# Tenant ID
$TENANT_ID = (az account show --query tenantId -o tsv)

# Application (Client) ID
$CLIENT_ID = $APP_ID

Write-Host "`nCopy these values for GitHub Secrets:" -ForegroundColor Cyan
Write-Host "AZURE_CLIENT_ID:        $CLIENT_ID" -ForegroundColor Yellow
Write-Host "AZURE_TENANT_ID:        $TENANT_ID" -ForegroundColor Yellow
Write-Host "AZURE_SUBSCRIPTION_ID:  $SUBSCRIPTION_ID" -ForegroundColor Yellow
```

**Security Note**: These are **identifiers**, not secrets. They're safe to use in GitHub repository secrets (not environment variables in logs).

## Part 2: GitHub Repository Setup

### Step 2.1: Configure Repository Secrets

Navigate to: `https://github.com/kjfisk-cplt/iflow/settings/secrets/actions`

Add three **repository secrets** (not environment secrets):

| Secret Name | Value | Description |
| --- | --- | --- |
| `AZURE_CLIENT_ID` | `<app-id>` | Service principal application (client) ID |
| `AZURE_TENANT_ID` | `<tenant-id>` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | `<subscription-id>` | Target Azure subscription ID |

**Steps**:

1. Click **New repository secret**
2. Name: `AZURE_CLIENT_ID`, Value: `<paste-app-id>`
3. Repeat for `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID`

**⚠️ Do NOT Store**:

- ❌ Client secrets (we're using OIDC, not secret-based auth)
- ❌ Storage account keys (we're using RBAC, not key-based auth)
- ❌ Any passwords or connection strings

### Step 2.2: Configure Branch Protection (Recommended)

Enable branch protection for `main` to enforce code review and prevent force pushes:

1. Navigate to: `https://github.com/kjfisk-cplt/iflow/settings/branches`
2. Click **Add branch protection rule**
3. Branch name pattern: `main`
4. Enable:
   - ✅ **Require a pull request before merging** (1 approval)
   - ✅ **Require status checks to pass before merging** (add `terraform-plan` job)
   - ✅ **Require branches to be up to date before merging**
   - ✅ **Do not allow bypassing the above settings**

### Step 2.3: Configure Environment Protection Rules (Optional, for Prod)

Add manual approval requirement for production deployments:

1. Navigate to: `https://github.com/kjfisk-cplt/iflow/settings/environments`
2. Click **New environment**, name: `production`
3. Enable **Required reviewers**: Add 1-2 approvers
4. Enable **Wait timer**: Optional 5-minute delay
5. Limit branches: Only `main` can deploy to production

Repeat for `test` environment if desired (lower protection requirements).

## Part 3: GitHub Actions Workflows

### Workflow 1: Terraform Plan (Pull Requests)

**File**: `.github/workflows/terraform-plan.yml`

```yaml
name: Terraform Plan

on:
  pull_request:
    branches: [main]
    paths:
      - 'infrastructure_as_code/environments/**'
      - '.github/workflows/terraform-plan.yml'

permissions:
  id-token: write      # Required for OIDC
  contents: read       # Read repository
  pull-requests: write # Post plan comments

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for git diff
      
      - name: Detect changed modules
        id: set-matrix
        run: |
          # Get changed files
          CHANGED_FILES=$(git diff --name-only origin/main...HEAD)
          
          # Extract unique module paths
          MODULES=$(echo "$CHANGED_FILES" | grep -oP 'infrastructure_as_code/environments/[^/]+/int_[^/]+' | sort -u | jq -R -s -c 'split("\n")[:-1]')
          
          echo "matrix={\"module\":$MODULES}" >> $GITHUB_OUTPUT
  
  plan:
    needs: detect-changes
    if: needs.detect-changes.outputs.matrix != '{"module":[]}'
    runs-on: ubuntu-latest
    strategy:
      matrix: ${{ fromJson(needs.detect-changes.outputs.matrix) }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.0
      
      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Extract module metadata
        id: metadata
        run: |
          MODULE_PATH="${{ matrix.module }}"
          ENV=$(echo $MODULE_PATH | cut -d'/' -f3)
          MODULE=$(echo $MODULE_PATH | cut -d'/' -f4)
          
          echo "env=$ENV" >> $GITHUB_OUTPUT
          echo "module=$MODULE" >> $GITHUB_OUTPUT
      
      - name: Terraform Init
        working-directory: ${{ matrix.module }}
        run: |
          terraform init \
            -backend-config="../backend.conf" \
            -backend-config="key=${{ steps.metadata.outputs.module }}.tfstate"
        env:
          ARM_USE_OIDC: true
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      
      - name: Terraform Validate
        working-directory: ${{ matrix.module }}
        run: terraform validate
      
      - name: Terraform Plan
        working-directory: ${{ matrix.module }}
        run: |
          terraform plan \
            -var="subscription_id=${{ secrets.AZURE_SUBSCRIPTION_ID }}" \
            -var="workload=iflow" \
            -var="env=${{ steps.metadata.outputs.env }}" \
            -out=tfplan \
            -no-color > plan.txt 2>&1
          cat plan.txt
        env:
          ARM_USE_OIDC: true
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          TF_VAR_tfstate_resource_group_name: rg-tfstate-iflow-${{ steps.metadata.outputs.env }}
          TF_VAR_tfstate_storage_account_name: stotfstateiflow${{ steps.metadata.outputs.env }}
      
      - name: Comment Plan on PR
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const planOutput = fs.readFileSync('${{ matrix.module }}/plan.txt', 'utf8');
            const truncatedPlan = planOutput.substring(0, 65000); // GitHub comment limit
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Terraform Plan: \`${{ steps.metadata.outputs.module }}\` (${steps.metadata.outputs.env})
            
            <details>
            <summary>Show Plan</summary>
            
            \`\`\`hcl
            ${truncatedPlan}
            \`\`\`
            
            </details>`
            })
```

### Workflow 2: Terraform Apply (Main Branch)

**File**: `.github/workflows/terraform-apply.yml`

```yaml
name: Terraform Apply

on:
  push:
    branches: [main]
    paths:
      - 'infrastructure_as_code/environments/**'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - test
          - prod
      module:
        description: 'Module to deploy (e.g., int_network)'
        required: true
        type: string

permissions:
  id-token: write
  contents: read

jobs:
  apply:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment || 'dev' }}  # Requires manual approval for prod
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.9.0
      
      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      
      - name: Determine module path
        id: path
        run: |
          if [ -n "${{ inputs.module }}" ]; then
            MODULE_PATH="infrastructure_as_code/environments/${{ inputs.environment }}/${{ inputs.module }}"
          else
            # Auto-detect from changed files (push event)
            CHANGED_FILES=$(git diff --name-only ${{ github.event.before }}..${{ github.sha }})
            MODULE_PATH=$(echo "$CHANGED_FILES" | grep -oP 'infrastructure_as_code/environments/[^/]+/int_[^/]+' | head -n 1)
          fi
          
          echo "module_path=$MODULE_PATH" >> $GITHUB_OUTPUT
          echo "Deploying: $MODULE_PATH"
      
      - name: Terraform Init
        working-directory: ${{ steps.path.outputs.module_path }}
        run: |
          MODULE_NAME=$(basename $(pwd))
          terraform init \
            -backend-config="../backend.conf" \
            -backend-config="key=${MODULE_NAME}.tfstate"
        env:
          ARM_USE_OIDC: true
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      
      - name: Terraform Validate
        working-directory: ${{ steps.path.outputs.module_path }}
        run: terraform validate
      
      - name: Terraform Plan
        working-directory: ${{ steps.path.outputs.module_path }}
        run: |
          terraform plan \
            -var="subscription_id=${{ secrets.AZURE_SUBSCRIPTION_ID }}" \
            -var="workload=iflow" \
            -var="env=${{ inputs.environment || 'dev' }}" \
            -out=tfplan
        env:
          ARM_USE_OIDC: true
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          TF_VAR_tfstate_resource_group_name: rg-tfstate-iflow-${{ inputs.environment || 'dev' }}
          TF_VAR_tfstate_storage_account_name: stotfstateiflow${{ inputs.environment || 'dev' }}
      
      - name: Terraform Apply
        working-directory: ${{ steps.path.outputs.module_path }}
        run: terraform apply -auto-approve tfplan
        env:
          ARM_USE_OIDC: true
          ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
          ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
      
      - name: Output deployment summary
        if: success()
        run: |
          echo "✓ Successfully deployed ${{ steps.path.outputs.module_path }}" >> $GITHUB_STEP_SUMMARY
```

## Part 4: Testing and Validation

### Test 1: Validate OIDC Authentication

Test the service principal can authenticate via OIDC:

**GitHub Actions** (add temporary test job):

```yaml
- name: Test Azure Authentication
  run: |
    az account show
    az storage account list --query "[].name" -o tsv
```

Expected: Output shows subscription details and storage accounts.

### Test 2: Verify State Backend Access

Test the service principal can read/write state files:

```yaml
- name: Test State Backend Access
  run: |
    az storage blob list \
      --account-name stotfstateiflowdev \
      --container-name tfstate \
      --auth-mode login \
      --query "[].name" -o tsv
```

Expected: Lists existing state files (or empty if no modules deployed yet).

### Test 3: Terraform Plan (Dry Run)

Trigger the `terraform-plan` workflow manually:

```powershell
# From local machine (requires GitHub CLI)
gh workflow run terraform-plan.yml
gh run watch
```

**Alternative**: Create a test pull request modifying any `.tf` file.

Expected:

- ✅ Workflow runs successfully
- ✅ Plan output posted as PR comment
- ✅ No authentication errors
- ✅ Backend state loaded correctly

### Test 4: Terraform Apply (Deployment)

**⚠️ Caution**: This deploys actual infrastructure.

```powershell
# Deploy int_network to dev (manual trigger)
gh workflow run terraform-apply.yml --field environment=dev --field module=int_network

# Monitor progress
gh run watch
```

Expected:

- ✅ Terraform Init succeeds
- ✅ Plan shows resources to create/modify
- ✅ Apply completes successfully
- ✅ State file created in Azure Storage

**Verification**:

```powershell
# Check state file exists
az storage blob list `
  --account-name stotfstateiflowdev `
  --container-name tfstate `
  --auth-mode login `
  --query "[?name=='int_network.tfstate'].{name:name, size:properties.contentLength, modified:properties.lastModified}" `
  --output table

# Verify resources created
az resource list --resource-group rg-iflow-network-dev --output table
```

## Deployment Order

Deploy modules in dependency order to satisfy cross-stack references:

### Phase 1: Foundation (No Dependencies)

1. **int_network** - VNet, NSG, Private DNS

   ```powershell
   gh workflow run terraform-apply.yml --field environment=dev --field module=int_network
   ```

### Phase 2: Monitoring and Identity (Depends on Network)

1. **int_monitoring** - Log Analytics, Application Insights
2. **int_common** - Managed Identity, App Service Plans

### Phase 3: Core Services (Depends on Network + Common)

1. **int_keyvault** - Key Vault with Private Endpoints
2. **int_storage** - Blob, Queue, Table storage
3. **int_messaging** - Event Hub, Service Bus

### Phase 4: Data Layer (Depends on Network + KeyVault)

1. **int_database** - Azure SQL

### Phase 5: Application Layer (Depends on All Previous)

1. **int_apim** - API Management
2. **int_common_functions** - Azure Functions
3. **int_common_logic** - Logic Apps
4. **int_ai** - Cognitive Services

**Gap Between Phases**: Wait for each phase to complete successfully before starting the next.

## Troubleshooting

### Error: `AADSTS700016: Application not found`

**Cause**: Service principal doesn't exist or incorrect Client ID.

**Solution**:

```powershell
# Verify app registration exists
az ad app show --id $APP_ID

# Recreate service principal if missing
az ad sp create --id $APP_ID
```

### Error: `AADSTS700051: Subject does not match`

**Cause**: OIDC federated credential subject doesn't match GitHub workflow context.

**Solution**:

```powershell
# List existing credentials
az ad app federated-credential list --id $APP_ID

# Verify subject pattern matches:
# - Main branch: repo:kjfisk-cplt/iflow:ref:refs/heads/main
# - Pull requests: repo:kjfisk-cplt/iflow:pull_request
# - Environment: repo:kjfisk-cplt/iflow:environment:<env-name>
```

### Error: `AuthorizationFailed: does not have authorization to perform action`

**Cause**: Missing RBAC role assignment.

**Solution**:

```powershell
# Check current role assignments
az role assignment list --assignee $APP_ID

# Grant missing roles (see Step 1.3)
```

### Error: `Backend initialization required`

**Cause**: State storage account doesn't exist.

**Solution**:

1. Complete state storage bootstrap: See [TERRAFORM_STATE_SETUP.md](./TERRAFORM_STATE_SETUP.md)
2. Verify storage account exists:

   ```powershell
   az storage account show --name stotfstateiflowdev
   ```

### Error: `Workflow does not have 'id-token: write' permission`

**Cause**: Missing OIDC permission in workflow.

**Solution**: Add to workflow YAML:

```yaml
permissions:
  id-token: write  # Required for OIDC
  contents: read
```

## Security Best Practices

✅ **Implemented**:

- OIDC federation (no secrets stored in GitHub)
- Least-privilege RBAC (Contributor + Storage Blob Data Contributor only)
- Environment protection rules (production requires approval)
- Branch protection (code review required)
- Short-lived tokens (automatic rotation)

🔒 **Recommended Enhancements**:

1. **IP Restrictions**: Limit GitHub Actions runner IP ranges in Azure Storage firewall
2. **Audit Logging**: Enable Azure Activity Log integration with Log Analytics
3. **Deployment Notifications**: Send alerts to Teams/Slack on successful deployments
4. **Cost Alerts**: Set budget alerts per environment
5. **Automated Testing**: Add `terraform fmt -check` and `tflint` validation steps

## Additional Resources

- **Azure OIDC GitHub Actions**: <https://learn.microsoft.com/azure/developer/github/connect-from-azure>
- **GitHub Environments**: <https://docs.github.com/en/actions/deployment/targeting-different-environments>
- **Terraform Backend**: <https://developer.hashicorp.com/terraform/language/settings/backends/azurerm>
- **iFlow State Setup**: [TERRAFORM_STATE_SETUP.md](./TERRAFORM_STATE_SETUP.md)

---

**Document Version**: 1.0  
**Last Updated**: April 12, 2026  
**Maintainer**: iFlow Platform Team
