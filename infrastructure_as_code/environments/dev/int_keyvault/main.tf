# ── Naming Module ─────────────────────────────────────────────────────────────

module "naming" {
  source   = "../_shared/naming"
  workload = var.workload
  env      = var.env
  location = var.location
}

# ── Current Client Config ─────────────────────────────────────────────────────
# Required for Key Vault tenant_id.

data "azurerm_client_config" "current" {}

# ── Remote State: Network Stack ───────────────────────────────────────────────
# Read subnet and private DNS zone IDs from int_network.

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = "int_network.tfstate"
  }
}

# ── Remote State: Common Stack ────────────────────────────────────────────────
# Read UAI principal ID from int_common for RBAC assignment.

data "terraform_remote_state" "common" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = "int_common.tfstate"
  }
}

# ── Resource Group ────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "keyvault" {
  name     = module.naming.rg_keyvault
  location = var.location
  tags     = local.tags
}

# ── Key Vault ─────────────────────────────────────────────────────────────────
# AVM: https://github.com/Azure/terraform-azurerm-avm-res-keyvault-vault
#
# RBAC authorization is enabled (legacy access policies are not used).
# Public network access is disabled — all access is via Private Endpoint.

module "keyvault" {
  source  = "Azure/avm-res-keyvault-vault/azurerm"
  version = "~> 0.10"

  name                = module.naming.kv_name
  location            = var.location
  resource_group_name = azurerm_resource_group.keyvault.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.tags

  sku_name                   = var.kv_sku
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  # Disable public access — all traffic must traverse the Private Endpoint.
  public_network_access_enabled = false

  # ── RBAC: Shared UAI ───────────────────────────────────────────────────────
  # Grants the platform User Assigned Managed Identity full secrets management.
  # Individual modules (Logic Apps, Functions, APIM) receive narrower roles
  # (Key Vault Secrets User) in their own stacks.

  role_assignments = {
    uai_secrets_officer = {
      role_definition_id_or_name = "Key Vault Secrets Officer"
      principal_id               = data.terraform_remote_state.common.outputs.uai_principal_id
    }
  }

  # ── Private Endpoint ───────────────────────────────────────────────────────
  # Deploys a Private Endpoint in the private-endpoints subnet and registers it
  # in the vaultcore private DNS zone that was created by int_network.

  private_endpoints = {
    vault = {
      name               = module.naming.pep_kv_name
      subnet_resource_id = data.terraform_remote_state.network.outputs.subnet_ids[var.pep_subnet_key]
      private_dns_zone_resource_ids = [
        data.terraform_remote_state.network.outputs.private_dns_zone_ids["privatelink.vaultcore.azure.net"]
      ]
      tags = local.tags
    }
  }

  enable_telemetry = false
}
