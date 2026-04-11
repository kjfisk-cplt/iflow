<#
.SYNOPSIS
    Bootstrap Terraform remote state storage infrastructure in Azure.

.DESCRIPTION
    This script creates the Azure Storage accounts and containers required for
    Terraform remote state management in the IFlow integration platform.
    
    Creates per environment:
    - Resource Group (rg-tfstate-iflow-{env})
    - Storage Account with versioning and soft delete (stotfstateiflow{env})
    - Blob container (tfstate)
    - RBAC role assignments (optional)

.PARAMETER Environment
    Target environment to bootstrap. Valid values: dev, test, prod.

.PARAMETER SubscriptionId
    Azure subscription ID where resources will be created.

.PARAMETER Location
    Azure region for resources. Default: swedencentral

.PARAMETER Workload
    Workload identifier used in resource naming. Default: iflow

.PARAMETER AssignRbac
    Assign Storage Blob Data Contributor role to current user. Default: $true

.PARAMETER ServicePrincipalId
    Optional: Service Principal Object ID to grant RBAC access (for CI/CD).

.PARAMETER WhatIf
    Preview changes without creating resources.

.EXAMPLE
    .\bootstrap-state-storage.ps1 -Environment dev -SubscriptionId "12345678-1234-1234-1234-123456789012"

.EXAMPLE
    .\bootstrap-state-storage.ps1 -Environment prod -SubscriptionId "..." -ServicePrincipalId "..."

.EXAMPLE
    .\bootstrap-state-storage.ps1 -Environment test -SubscriptionId "..." -WhatIf

.NOTES
    Author: IFlow Platform Team
    Version: 1.0
    Prerequisites: Azure CLI authenticated with Contributor permissions
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('dev', 'test', 'prod')]
    [string]$Environment,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$')]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$Location = 'swedencentral',

    [Parameter(Mandatory = $false)]
    [string]$Workload = 'iflow',

    [Parameter(Mandatory = $false)]
    [bool]$AssignRbac = $true,

    [Parameter(Mandatory = $false)]
    [string]$ServicePrincipalId
)

#Requires -Modules @{ ModuleName='Az.Accounts'; ModuleVersion='2.0.0' }

$ErrorActionPreference = 'Stop'

# Configuration
$resourceGroupName = "rg-tfstate-$Workload-$Environment"
$storageAccountName = "stotfstate$Workload$Environment"
$containerName = 'tfstate'
$softDeleteDays = 30

# SKU selection based on environment
$sku = if ($Environment -eq 'prod') { 'Standard_GRS' } else { 'Standard_LRS' }

# Tags
$tags = @{
    Environment = $Environment
    Workload    = 'Terraform-State'
    ManagedBy   = 'IaC'
}

if ($Environment -eq 'prod') {
    $tags['Criticality'] = 'High'
}

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "Terraform State Storage Bootstrap" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan

Write-Host "Environment:       $Environment" -ForegroundColor White
Write-Host "Subscription:      $SubscriptionId" -ForegroundColor White
Write-Host "Location:          $Location" -ForegroundColor White
Write-Host "Resource Group:    $resourceGroupName" -ForegroundColor White
Write-Host "Storage Account:   $storageAccountName" -ForegroundColor White
Write-Host "Container:         $containerName" -ForegroundColor White
Write-Host "SKU:               $sku" -ForegroundColor White
Write-Host "Soft Delete:       $softDeleteDays days`n" -ForegroundColor White

if ($PSCmdlet.ShouldProcess("Azure subscription $SubscriptionId", "Create Terraform state infrastructure")) {
    
    # Step 1: Verify Azure CLI is available
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
        Write-Error "Failed to set subscription. Verify ID and permissions."
        exit 1
    }

    $currentSub = az account show --query "{Name:name, Id:id}" -o json | ConvertFrom-Json
    Write-Host "✓ Using subscription: $($currentSub.Name) ($($currentSub.Id))`n" -ForegroundColor Green

    # Step 3: Create Resource Group
    Write-Host "Creating resource group..." -ForegroundColor Yellow
    $rgExists = az group exists --name $resourceGroupName
    
    if ($rgExists -eq 'true') {
        Write-Host "✓ Resource group already exists: $resourceGroupName" -ForegroundColor Green
    }
    else {
        $tagString = ($tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' '
        
        az group create `
            --name $resourceGroupName `
            --location $Location `
            --tags $tagString

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Created resource group: $resourceGroupName" -ForegroundColor Green
        }
        else {
            Write-Error "Failed to create resource group"
            exit 1
        }
    }

    # Step 4: Create Storage Account
    Write-Host "`nCreating storage account..." -ForegroundColor Yellow
    $stoExists = az storage account check-name --name $storageAccountName --query "nameAvailable" -o tsv
    
    if ($stoExists -eq 'false') {
        Write-Host "✓ Storage account already exists: $storageAccountName" -ForegroundColor Green
        
        # Verify it's in correct resource group
        $stoRg = az storage account show --name $storageAccountName --query "resourceGroup" -o tsv 2>$null
        if ($stoRg -ne $resourceGroupName) {
            Write-Error "Storage account exists but in different resource group: $stoRg"
            exit 1
        }
    }
    else {
        $tagString = ($tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' '
        
        az storage account create `
            --name $storageAccountName `
            --resource-group $resourceGroupName `
            --location $Location `
            --sku $sku `
            --kind StorageV2 `
            --allow-blob-public-access false `
            --min-tls-version TLS1_2 `
            --https-only true `
            --tags $tagString

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Created storage account: $storageAccountName ($sku)" -ForegroundColor Green
        }
        else {
            Write-Error "Failed to create storage account"
            exit 1
        }
    }

    # Step 5: Enable Blob Versioning
    Write-Host "`nEnabling blob versioning..." -ForegroundColor Yellow
    az storage account blob-service-properties update `
        --account-name $storageAccountName `
        --resource-group $resourceGroupName `
        --enable-versioning true

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Blob versioning enabled (infinite retention)" -ForegroundColor Green
    }

    # Step 6: Enable Soft Delete
    Write-Host "`nEnabling soft delete..." -ForegroundColor Yellow
    az storage account blob-service-properties update `
        --account-name $storageAccountName `
        --resource-group $resourceGroupName `
        --enable-delete-retention true `
        --delete-retention-days $softDeleteDays

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Soft delete enabled ($softDeleteDays days retention)" -ForegroundColor Green
    }

    # Step 7: Create Container
    Write-Host "`nCreating blob container..." -ForegroundColor Yellow
    $containerExists = az storage container exists `
        --account-name $storageAccountName `
        --name $containerName `
        --auth-mode login `
        --query "exists" -o tsv 2>$null

    if ($containerExists -eq 'true') {
        Write-Host "✓ Container already exists: $containerName" -ForegroundColor Green
    }
    else {
        az storage container create `
            --name $containerName `
            --account-name $storageAccountName `
            --auth-mode login

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Created container: $containerName" -ForegroundColor Green
        }
        else {
            Write-Warning "Failed to create container. May need RBAC permissions first."
        }
    }

    # Step 8: Assign RBAC to Current User
    if ($AssignRbac) {
        Write-Host "`nAssigning RBAC to current user..." -ForegroundColor Yellow
        
        $currentUser = az ad signed-in-user show --query "id" -o tsv 2>$null
        if ($currentUser) {
            $scope = "/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName"
            
            az role assignment create `
                --assignee $currentUser `
                --role "Storage Blob Data Contributor" `
                --scope $scope `
                2>$null

            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ Assigned 'Storage Blob Data Contributor' to current user" -ForegroundColor Green
            }
            else {
                Write-Warning "Role assignment may already exist (this is OK)"
            }
        }
        else {
            Write-Warning "Could not determine current user. Skipping RBAC assignment."
        }
    }

    # Step 9: Assign RBAC to Service Principal (if provided)
    if ($ServicePrincipalId) {
        Write-Host "`nAssigning RBAC to service principal..." -ForegroundColor Yellow
        
        $scope = "/subscriptions/$SubscriptionId/resourceGroups/$resourceGroupName/providers/Microsoft.Storage/storageAccounts/$storageAccountName"
        
        az role assignment create `
            --assignee $ServicePrincipalId `
            --role "Storage Blob Data Contributor" `
            --scope $scope `
            2>$null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Assigned 'Storage Blob Data Contributor' to service principal" -ForegroundColor Green
        }
        else {
            Write-Warning "Role assignment may already exist (this is OK)"
        }
    }

    # Summary
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "Bootstrap Complete" -ForegroundColor Green
    Write-Host "============================================================`n" -ForegroundColor Cyan

    Write-Host "Resources created:" -ForegroundColor White
    Write-Host "  Resource Group:    $resourceGroupName" -ForegroundColor White
    Write-Host "  Storage Account:   $storageAccountName" -ForegroundColor White
    Write-Host "  Container:         $containerName" -ForegroundColor White
    Write-Host "  Replication:       $sku" -ForegroundColor White
    Write-Host "  Versioning:        Enabled" -ForegroundColor White
    Write-Host "  Soft Delete:       $softDeleteDays days`n" -ForegroundColor White

    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Verify backend configuration in: infrastructure_as_code/environments/$Environment/backend.conf" -ForegroundColor White
    Write-Host "  2. Initialize Terraform in a module:" -ForegroundColor White
    Write-Host "     cd infrastructure_as_code/environments/$Environment/int_network" -ForegroundColor Cyan
    Write-Host "     terraform init -backend-config=`"../backend.conf`" -backend-config=`"key=int_network.tfstate`"`n" -ForegroundColor Cyan

    Write-Host "Documentation:" -ForegroundColor Yellow
    Write-Host "  - Setup Guide:    infrastructure_as_code/docs/TERRAFORM_STATE_SETUP.md" -ForegroundColor White
    Write-Host "  - CI/CD Setup:    infrastructure_as_code/docs/CICD_PREREQUISITES.md" -ForegroundColor White
    Write-Host "  - Recovery Guide: infrastructure_as_code/docs/runbooks/STATE_RECOVERY.md`n" -ForegroundColor White
}
else {
    Write-Host "`n[WhatIf] Would create:" -ForegroundColor Yellow
    Write-Host "  - Resource Group: $resourceGroupName" -ForegroundColor White
    Write-Host "  - Storage Account: $storageAccountName ($sku)" -ForegroundColor White
    Write-Host "  - Container: $containerName" -ForegroundColor White
    Write-Host "  - Blob Versioning: Enabled" -ForegroundColor White
    Write-Host "  - Soft Delete: $softDeleteDays days`n" -ForegroundColor White
}
