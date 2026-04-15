# ── Naming Module ─────────────────────────────────────────────────────────────

module "naming" {
  source   = "../_shared/naming"
  workload = var.workload
  env      = var.env
  location = var.location
}

# ── Resource Group ────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "common" {
  name     = module.naming.rg_common
  location = var.location
  tags     = local.tags
}

# ── User Assigned Managed Identity ───────────────────────────────────────────
# AVM: https://github.com/Azure/terraform-azurerm-avm-res-managedidentity-userassignedidentity

module "uai" {
  source  = "Azure/avm-res-managedidentity-userassignedidentity/azurerm"
  version = "~> 0.3"

  name                = module.naming.identity_name
  location            = var.location
  resource_group_name = azurerm_resource_group.common.name
  tags                = local.tags

  enable_telemetry = false
}

# ── App Service Plan: Logic Apps Standard (Elastic Premium) ──────────────────
# AVM: https://github.com/Azure/terraform-azurerm-avm-res-web-serverfarm

module "asp_logic" {
  source  = "Azure/avm-res-web-serverfarm/azurerm"
  version = "~> 0.4"

  name                = module.naming.asp_logic_name
  location            = var.location
  resource_group_name = azurerm_resource_group.common.name
  tags                = local.tags

  os_type  = "Windows"
  sku_name = var.asp_logic_sku

  enable_telemetry = false
}

# ── App Service Plan: Azure Functions (Elastic Premium) ──────────────────────

module "asp_functions" {
  source  = "Azure/avm-res-web-serverfarm/azurerm"
  version = "~> 0.4"

  name                = module.naming.asp_functions_name
  location            = var.location
  resource_group_name = azurerm_resource_group.common.name
  tags                = local.tags

  os_type  = "Windows"
  sku_name = var.asp_functions_sku

  enable_telemetry = false
}

# ── App Service Plan: Web Applications ───────────────────────────────────────

# module "asp_web" {
#   source  = "Azure/avm-res-web-serverfarm/azurerm"
#   version = "~> 0.4"

#   name                = module.naming.asp_web_name
#   location            = var.location
#   resource_group_name = azurerm_resource_group.common.name
#   tags                = local.tags

#   os_type  = "Windows"
#   sku_name = var.asp_web_sku

#   enable_telemetry = false
# }

# ── RBAC: UAI Subscription-Scope Role ────────────────────────────────────────
# Assigns the UAI a role at subscription scope for cross-resource access.
# Enabled via enable_uai_subscription_role_assignment = true.

resource "azurerm_role_assignment" "uai_subscription" {
  count = var.enable_uai_subscription_role_assignment ? 1 : 0

  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = var.uai_subscription_role
  principal_id         = module.uai.principal_id
}
