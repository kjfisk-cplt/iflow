<#
.SYNOPSIS
    Configure Azure service principal with OIDC federated credentials for GitHub Actions.

.DESCRIPTION
    This script automates the setup of a service principal with federated credentials
    for keyless (OIDC) authentication from GitHub Actions to Azure.
    
    Creates:
    - Service Principal (if not exists)
    - Federated Credentials for:
      * Main branch deployments
      * Pull request validation
      * Environment-specific deployments (dev, test, prod)
    - RBAC role assignments:
      * Contributor (subscription scope)
      * Storage Blob Data Contributor (state storage scope)

.PARAMETER SubscriptionId
    Azure subscription ID where resources exist.

.PARAMETER GitHubOrg
    GitHub organization name (e.g., "kjfisk-cplt").

.PARAMETER GitHubRepo
    GitHub repository name (e.g., "iflow").

.PARAMETER ServicePrincipalName
    Name for the service principal. Default: gh-actions-iflow

.PARAMETER StateStorageResourceGroups
    Comma-separated list of state storage resource group names.
    Default: rg-tfstate-iflow-dev,rg-tfstate-iflow-test,rg-tfstate-iflow-prod

.PARAMETER WhatIf
    Preview changes without creating resources.

.EXAMPLE
    .\configure-oidc.ps1 -SubscriptionId "..." -GitHubOrg "kjfisk-cplt" -GitHubRepo "iflow"

.EXAMPLE
    .\configure-oidc.ps1 -SubscriptionId "..." -GitHubOrg "kjfisk-cplt" -GitHubRepo "iflow" -WhatIf

.NOTES
    Author: IFlow Platform Team
    Version: 1.0
    Prerequisites: 
    - Azure CLI with permissions to create service principals and role assignments
    - GitHub repository with Actions enabled
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$GitHubOrg,

    [Parameter(Mandatory = $true)]
    [string]$GitHubRepo,

    [Parameter(Mandatory = $false)]
    [string]$ServicePrincipalName = 'gh-actions-iflow',

    [Parameter(Mandatory = $false)]
    [string]$StateStorageResourceGroups = 'rg-tfstate-iflow-dev,rg-tfstate-iflow-test,rg-tfstate-iflow-prod'
)

$ErrorActionPreference = 'Stop'

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "GitHub Actions OIDC Configuration" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

Write-Host "Subscription:          $SubscriptionId" -ForegroundColor White
Write-Host "GitHub Repository:     $GitHubOrg/$GitHubRepo" -ForegroundColor White
Write-Host "Service Principal:     $ServicePrincipalName`n" -ForegroundColor White

if ($PSCmdlet.ShouldProcess("Azure subscription $SubscriptionId", "Configure OIDC for GitHub Actions")) {
    
    # Step 1: Verify Azure CLI
    Write-Host "Verifying Azure CLI..." -ForegroundColor Yellow
    try {
        $null = az version 2>$null
    }
    catch {
        Write-Error "Azure CLI not found. Please install: https://aka.ms/azure-cli"
        exit 1
    }

    # Step 2: Set subscription context
    Write-Host "Setting subscription context..." -ForegroundColor Yellow
    az account set --subscription $SubscriptionId
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to set subscription"
        exit 1
    }

    $currentSub = az account show --query "{Name:name, Id:id, TenantId:tenantId}" -o json | ConvertFrom-Json
    Write-Host "✓ Subscription: $($currentSub.Name)" -ForegroundColor Green
    Write-Host "✓ Tenant ID:    $($currentSub.TenantId)`n" -ForegroundColor Green

    # Step 3: Create or get Service Principal
    Write-Host "Checking for existing service principal..." -ForegroundColor Yellow
    $sp = az ad sp list --display-name $ServicePrincipalName --query "[0]" -o json 2>$null | ConvertFrom-Json

    if ($sp) {
        Write-Host "✓ Service principal exists: $ServicePrincipalName" -ForegroundColor Green
        Write-Host "  App ID: $($sp.appId)" -ForegroundColor White
        Write-Host "  Object ID: $($sp.id)`n" -ForegroundColor White
        
        $appId = $sp.appId
        $spObjectId = $sp.id
    }
    else {
        Write-Host "Creating new service principal..." -ForegroundColor Yellow
        
        $sp = az ad sp create-for-rbac `
            --name $ServicePrincipalName `
            --role Contributor `
            --scopes "/subscriptions/$SubscriptionId" `
            --query "{appId:appId, password:password}" -o json | ConvertFrom-Json

        if ($LASTEXITCODE -eq 0) {
            $appId = $sp.appId
            
            # Get object ID (az ad sp create-for-rbac doesn't return it)
            Start-Sleep -Seconds 5  # Wait for propagation
            $spDetails = az ad sp show --id $appId --query "id" -o tsv
            $spObjectId = $spDetails
            
            Write-Host "✓ Created service principal: $ServicePrincipalName" -ForegroundColor Green
            Write-Host "  App ID: $appId" -ForegroundColor White
            Write-Host "  Object ID: $spObjectId" -ForegroundColor White
            Write-Warning "Password generated but will not be used (OIDC is keyless)`n"
        }
        else {
            Write-Error "Failed to create service principal"
            exit 1
        }
    }

    # Step 4: Create Federated Credentials
    Write-Host "Configuring federated credentials..." -ForegroundColor Yellow

    $credentials = @(
        @{
            Name        = "$ServicePrincipalName-main"
            Subject     = "repo:$GitHubOrg/$($GitHubRepo):ref:refs/heads/main"
            Description = "Main branch deployments"
        },
        @{
            Name        = "$ServicePrincipalName-pr"
            Subject     = "repo:$GitHubOrg/$($GitHubRepo):pull_request"
            Description = "Pull request validation"
        },
        @{
            Name        = "$ServicePrincipalName-env-dev"
            Subject     = "repo:$GitHubOrg/$($GitHubRepo):environment:dev"
            Description = "Dev environment deployments"
        },
        @{
            Name        = "$ServicePrincipalName-env-test"
            Subject     = "repo:$GitHubOrg/$($GitHubRepo):environment:test"
            Description = "Test environment deployments"
        },
        @{
            Name        = "$ServicePrincipalName-env-prod"
            Subject     = "repo:$GitHubOrg/$($GitHubRepo):environment:prod"
            Description = "Prod environment deployments"
        }
    )

    foreach ($cred in $credentials) {
        $existing = az ad app federated-credential list `
            --id $appId `
            --query "[?name=='$($cred.Name)'].name" -o tsv 2>$null

        if ($existing) {
            Write-Host "  ✓ Federated credential exists: $($cred.Name)" -ForegroundColor Green
        }
        else {
            $body = @{
                name        = $cred.Name
                issuer      = "https://token.actions.githubusercontent.com"
                subject     = $cred.Subject
                description = $cred.Description
                audiences   = @("api://AzureADTokenExchange")
            } | ConvertTo-Json

            $tempFile = [System.IO.Path]::GetTempFileName()
            $body | Out-File -FilePath $tempFile -Encoding utf8

            az ad app federated-credential create `
                --id $appId `
                --parameters $tempFile

            Remove-Item -Path $tempFile

            if ($LASTEXITCODE -eq 0) {
                Write-Host "  ✓ Created: $($cred.Name)" -ForegroundColor Green
                Write-Host "    Subject: $($cred.Subject)" -ForegroundColor DarkGray
            }
            else {
                Write-Warning "Failed to create credential: $($cred.Name)"
            }
        }
    }

    Write-Host ""

    # Step 5: Assign Contributor role (may already exist from creation)
    Write-Host "Assigning Contributor role at subscription scope..." -ForegroundColor Yellow
    
    az role assignment create `
        --assignee $appId `
        --role "Contributor" `
        --scope "/subscriptions/$SubscriptionId" `
        2>$null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Assigned Contributor role" -ForegroundColor Green
    }
    else {
        Write-Host "✓ Contributor role already assigned (OK)" -ForegroundColor Green
    }

    # Step 6: Assign Storage Blob Data Contributor to state storage RGs
    Write-Host "`nAssigning Storage Blob Data Contributor to state storage..." -ForegroundColor Yellow
    
    $rgList = $StateStorageResourceGroups -split ','
    foreach ($rg in $rgList) {
        $rg = $rg.Trim()
        
        # Check if RG exists
        $rgExists = az group exists --name $rg
        if ($rgExists -eq 'false') {
            Write-Warning "Resource group does not exist: $rg (Run bootstrap script first)"
            continue
        }

        # Get storage accounts in RG
        $storageAccounts = az storage account list `
            --resource-group $rg `
            --query "[].{Name:name, Id:id}" -o json | ConvertFrom-Json

        if ($storageAccounts) {
            foreach ($sto in $storageAccounts) {
                az role assignment create `
                    --assignee $appId `
                    --role "Storage Blob Data Contributor" `
                    --scope $sto.Id `
                    2>$null

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✓ $rg -> $($sto.Name)" -ForegroundColor Green
                }
                else {
                    Write-Host "  ✓ $rg -> $($sto.Name) (already assigned)" -ForegroundColor Green
                }
            }
        }
        else {
            Write-Warning "No storage accounts found in: $rg"
        }
    }

    # Summary
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "OIDC Configuration Complete" -ForegroundColor Green
    Write-Host "============================================================`n" -ForegroundColor Cyan

    Write-Host "Service Principal Details:" -ForegroundColor White
    Write-Host "  Name:      $ServicePrincipalName" -ForegroundColor White
    Write-Host "  App ID:    $appId" -ForegroundColor White
    Write-Host "  Object ID: $spObjectId" -ForegroundColor White
    Write-Host "  Tenant ID: $($currentSub.TenantId)`n" -ForegroundColor White

    Write-Host "Federated Credentials Created:" -ForegroundColor White
    foreach ($cred in $credentials) {
        Write-Host "  - $($cred.Name)" -ForegroundColor White
    }

    Write-Host "`nGitHub Secrets Required:" -ForegroundColor Yellow
    Write-Host "  Navigate to: https://github.com/$GitHubOrg/$GitHubRepo/settings/secrets/actions`n" -ForegroundColor White
    
    Write-Host "  Secret Name:              Value:" -ForegroundColor White
    Write-Host "  ────────────────────────  ────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  AZURE_CLIENT_ID           $appId" -ForegroundColor Cyan
    Write-Host "  AZURE_TENANT_ID           $($currentSub.TenantId)" -ForegroundColor Cyan
    Write-Host "  AZURE_SUBSCRIPTION_ID     $SubscriptionId`n" -ForegroundColor Cyan

    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Add the three secrets above to your GitHub repository" -ForegroundColor White
    Write-Host "  2. Configure GitHub Environments (Settings → Environments):" -ForegroundColor White
    Write-Host "     - dev (no protection rules)" -ForegroundColor White
    Write-Host "     - test (optional: required reviewers)" -ForegroundColor White
    Write-Host "     - prod (required reviewers + deployment branches: main only)" -ForegroundColor White
    Write-Host "  3. Test the setup by pushing a PR to validate terraform-plan.yml workflow" -ForegroundColor White
    Write-Host "  4. For detailed CI/CD setup, see: infrastructure_as_code/docs/CICD_PREREQUISITES.md`n" -ForegroundColor White

    Write-Host "Testing OIDC Locally (Optional):" -ForegroundColor Yellow
    Write-Host "  # Set environment variables" -ForegroundColor White
    Write-Host "  `$env:ARM_CLIENT_ID = '$appId'" -ForegroundColor Cyan
    Write-Host "  `$env:ARM_TENANT_ID = '$($currentSub.TenantId)'" -ForegroundColor Cyan
    Write-Host "  `$env:ARM_SUBSCRIPTION_ID = '$SubscriptionId'" -ForegroundColor Cyan
    Write-Host "  `$env:ARM_USE_OIDC = 'true'`n" -ForegroundColor Cyan
}
else {
    Write-Host "`n[WhatIf] Would configure:" -ForegroundColor Yellow
    Write-Host "  - Service Principal: $ServicePrincipalName" -ForegroundColor White
    Write-Host "  - Federated Credentials: 5 (main, PR, 3 environments)" -ForegroundColor White
    Write-Host "  - RBAC: Contributor + Storage Blob Data Contributor`n" -ForegroundColor White
}
