# ── Naming Module ─────────────────────────────────────────────────────────────

module "naming" {
  source   = "../_shared/naming"
  workload = var.workload
  env      = var.env
  location = var.location
}

# ── Remote State: Network Stack ───────────────────────────────────────────────
# Read outputs from int_network for Private Link Scope

data "terraform_remote_state" "network" {
  backend = "azurerm"
  config = {
    resource_group_name  = var.tfstate_resource_group_name
    storage_account_name = var.tfstate_storage_account_name
    container_name       = var.tfstate_container_name
    key                  = "int_network.tfstate"
  }
}

# ── Resource Group ────────────────────────────────────────────────────────────

resource "azurerm_resource_group" "monitoring" {
  name     = module.naming.rg_monitoring
  location = var.location
  tags     = local.tags
}

# ── Log Analytics Workspace: Diagnostics (Platform Logs) ──────────────────────
# AVM: https://github.com/Azure/terraform-azurerm-avm-res-operationalinsights-workspace

module "log_analytics_diagnostics" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "~> 0.5"

  name                = module.naming.log_monitoring_name
  location            = var.location
  resource_group_name = azurerm_resource_group.monitoring.name
  tags                = local.tags

  log_analytics_workspace_sku                        = var.log_analytics_sku
  log_analytics_workspace_retention_in_days          = var.log_analytics_retention_in_days
  log_analytics_workspace_internet_ingestion_enabled = "false"
  log_analytics_workspace_internet_query_enabled     = "false"

  # Link to Private Link Scope from int_network
  monitor_private_link_scoped_resource = {
    pls = {
      resource_id = data.terraform_remote_state.network.outputs.pls_monitoring_id
    }
  }

  enable_telemetry = false
}

# ── Log Analytics Workspace: Tracking (Business Events) ───────────────────────

module "log_analytics_tracking" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "~> 0.5"

  name                = module.naming.log_tracking_name
  location            = var.location
  resource_group_name = azurerm_resource_group.monitoring.name
  tags                = local.tags

  log_analytics_workspace_sku                        = var.log_analytics_sku
  log_analytics_workspace_retention_in_days          = var.log_analytics_retention_in_days
  log_analytics_workspace_internet_ingestion_enabled = "false"
  log_analytics_workspace_internet_query_enabled     = "false"

  # Link to Private Link Scope from int_network
  monitor_private_link_scoped_resource = {
    pls = {
      resource_id = data.terraform_remote_state.network.outputs.pls_monitoring_id
    }
  }

  enable_telemetry = false
}

# ── Application Insights: APIM ────────────────────────────────────────────────
# AVM: https://github.com/Azure/terraform-azurerm-avm-res-insights-component

module "appi_apim" {
  source  = "Azure/avm-res-insights-component/azurerm"
  version = "~> 0.3"

  name                = module.naming.appi_apim_name
  location            = var.location
  resource_group_name = azurerm_resource_group.monitoring.name
  workspace_id        = module.log_analytics_diagnostics.resource_id
  tags                = local.tags

  application_type           = "web"
  internet_ingestion_enabled = false
  internet_query_enabled     = false

  # Link to Private Link Scope from int_network
  monitor_private_link_scope = {
    pls = {
      resource_id = data.terraform_remote_state.network.outputs.pls_monitoring_id
    }
  }

  enable_telemetry = false
}

# ── Application Insights: Logic Apps ──────────────────────────────────────────

module "appi_logic" {
  source  = "Azure/avm-res-insights-component/azurerm"
  version = "~> 0.3"

  name                = module.naming.appi_logic_name
  location            = var.location
  resource_group_name = azurerm_resource_group.monitoring.name
  workspace_id        = module.log_analytics_diagnostics.resource_id
  tags                = local.tags

  application_type           = "web"
  internet_ingestion_enabled = false
  internet_query_enabled     = false

  # Link to Private Link Scope from int_network
  monitor_private_link_scope = {
    pls = {
      resource_id = data.terraform_remote_state.network.outputs.pls_monitoring_id
    }
  }

  enable_telemetry = false
}

# ── Application Insights: Azure Functions ─────────────────────────────────────

module "appi_functions" {
  source  = "Azure/avm-res-insights-component/azurerm"
  version = "~> 0.3"

  name                = module.naming.appi_functions_name
  location            = var.location
  resource_group_name = azurerm_resource_group.monitoring.name
  workspace_id        = module.log_analytics_diagnostics.resource_id
  tags                = local.tags

  application_type           = "web"
  internet_ingestion_enabled = false
  internet_query_enabled     = false

  # Link to Private Link Scope from int_network
  monitor_private_link_scope = {
    pls = {
      resource_id = data.terraform_remote_state.network.outputs.pls_monitoring_id
    }
  }

  enable_telemetry = false
}

# ── Action Group ──────────────────────────────────────────────────────────────

resource "azurerm_monitor_action_group" "alerts" {
  name                = "ag-${var.workload}-alerts-${local.env_suffix}"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "iflow${local.env_suffix}"
  tags                = local.tags

  dynamic "email_receiver" {
    for_each = var.action_group_email_receivers
    content {
      name                    = email_receiver.value.name
      email_address           = email_receiver.value.email_address
      use_common_alert_schema = email_receiver.value.use_common_alert_schema
    }
  }
}
