# main.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.2.0"

    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 1.11"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "<YOUR_SUBSCRIPTION_ID>"
}

# Data Sources
data "azurerm_client_config" "current" {}

# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.common_tags
}


# Storage Account
resource "azurerm_storage_account" "storage" {
  name                     = format("%s%s", replace(local.base_name, "-", ""), "files")
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = var.storage_account_tier
  account_replication_type = var.storage_account_replication_type
  tags                     = local.common_tags
}

# Storage Container for Search
resource "azurerm_storage_container" "search_container" {
  name                  = "search"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}



# Key Vault with Network Restrictions
resource "azurerm_key_vault" "kv" {
  name                = "kv-${local.base_name}-swd"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = var.key_vault_sku_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.common_tags
}

# Application Insights
resource "azurerm_application_insights" "appinsights" {
  name                = "appi-${local.base_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
  tags                = local.common_tags
}
# App Service Plan
resource "azurerm_app_service_plan" "asp" {
  name                = "ASP-${local.base_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku {
    tier = var.app_service_plan_sku_tier
    size = var.app_service_plan_sku_size
  }

  timeouts {
    delete = "15m"
  }
  tags = local.common_tags
}

# App Service with Network Configuration
resource "azurerm_app_service" "appservice" {
  name                = "APP-${local.base_name}-swd"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  app_service_plan_id = azurerm_app_service_plan.asp.id
  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.appinsights.instrumentation_key
  }
  tags = local.common_tags

  identity {
    type = "SystemAssigned"
  }

}

# Azure Search Service
resource "azurerm_search_service" "search" {
  name                = "search-${local.base_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = var.search_service_sku_name
  replica_count       = var.search_service_sku_capacity
  partition_count     = var.search_service_partition_count
  tags                = local.common_tags
}

# Configure restapi provider
provider "restapi" {
  uri                  = "https://${azurerm_search_service.search.name}.search.windows.net"
  write_returns_object = true
  debug                = true

  headers = {
    "api-key"      = azurerm_search_service.search.primary_key
    "Content-Type" = "application/json"
  }

  create_method  = "POST"
  update_method  = "PUT"
  destroy_method = "DELETE"
}

# Create Search Index
resource "restapi_object" "search_index" {
  path         = "/indexes"
  query_string = "api-version=2023-10-01-Preview"
  data         = jsonencode(local.search_index_json)
  id_attribute = "name"
  depends_on   = [azurerm_search_service.search]
}

# Create Data Source
resource "restapi_object" "search_datasource" {
  path         = "/datasources"
  query_string = "api-version=2023-10-01-Preview"
  data         = jsonencode(local.search_datasource_json)
  id_attribute = "name"
  depends_on   = [azurerm_storage_account.storage]
}

# Create Indexer
resource "restapi_object" "search_indexer" {
  path         = "/indexers"
  query_string = "api-version=2023-10-01-Preview"
  data         = jsonencode(local.search_indexer_json)
  id_attribute = "name"
  depends_on = [
    restapi_object.search_index,
    restapi_object.search_datasource,
    azurerm_storage_blob.sample_file
  ]
}

# Upload File to Blob Storage
resource "azurerm_storage_blob" "sample_file" {
  name                   = "AlisonKaras.pdf"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.search_container.name
  type                   = "Block"
  source                 = var.sample_file_path
}

# Cognitive Account
resource "azurerm_cognitive_account" "account" {
  name                = "${local.base_name}-oai"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "OpenAI"
  sku_name            = "S0"
}



# Cognitive Deployments
resource "azurerm_cognitive_deployment" "deployments" {
  for_each = var.models

  name                 = each.key
  cognitive_account_id = azurerm_cognitive_account.account.id
  rai_policy_name      = azapi_resource.content_filters[each.value.rai_policy_name].name
  model {
    format  = each.value.model_format
    name    = each.value.model_name
    version = each.value.model_version
  }
  sku {
    name     = "Standard"
    capacity = each.value.scale_capacity
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [model]
  }
  
}

# Cognitive Content Filters
resource "azapi_resource" "content_filters" {
  for_each = var.content_filters

  name                      = each.key
  type                      = "Microsoft.CognitiveServices/accounts/raiPolicies@2023-10-01-preview"
  parent_id                 = azurerm_cognitive_account.account.id
  schema_validation_enabled = false
  body = jsonencode({
    properties = each.value
  })
  
    depends_on = [azurerm_cognitive_account.account] 

}

# Key Vault Access Policy
resource "azurerm_key_vault_access_policy" "access_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge",
    "Recover",
    "Backup",
    "Restore"
  ]
}

# Key Vault Secrets
resource "azurerm_key_vault_secret" "cognitive_endpoint" {
  name         = "AZURE-OPENAI-ENDPOINT"
  value        = azurerm_cognitive_account.account.endpoint
  key_vault_id = azurerm_key_vault.kv.id
  depends_on = [
    azurerm_key_vault_access_policy.access_policy
  ]
}

resource "azurerm_key_vault_secret" "cognitive_api_key" {
  name         = "AZURE-OPENAI-KEY"
  value        = azurerm_cognitive_account.account.primary_access_key
  key_vault_id = azurerm_key_vault.kv.id
  depends_on = [
    azurerm_key_vault_access_policy.access_policy
  ]
}

resource "azurerm_key_vault_secret" "search_key" {
  name         = "SEARCH-KEY"
  value        = azurerm_search_service.search.primary_key
  key_vault_id = azurerm_key_vault.kv.id
  depends_on = [
    azurerm_key_vault_access_policy.access_policy
  ]
}

resource "azurerm_key_vault_secret" "search_url" {
  name         = "AZURE-SEARCH-ENDPOINT"
  value        = "https://search-${local.base_name}.search.windows.net"
  key_vault_id = azurerm_key_vault.kv.id
  depends_on = [
    azurerm_key_vault_access_policy.access_policy
  ]
}

resource "azurerm_key_vault_secret" "search_index_name" {
  name         = "AZURE-SEARCH-INDEX-NAME"
  value        = local.search_index_json.name
  key_vault_id = azurerm_key_vault.kv.id
  depends_on = [
    azurerm_key_vault_access_policy.access_policy
  ]
}
