# variables.tf
variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "location" {
  type        = string
  description = "Azure region to deploy resources"
  default     = "East US"
}

variable "app_service_plan_sku_tier" {
  type        = string
  description = "Tier for the app service plan"
  default     = "free"
}

variable "app_service_plan_sku_size" {
  type        = string
  description = "Size for the app service plan"
  default     = "F1"
}

variable "storage_account_replication_type" {
  type        = string
  description = "Replication type for the storage account"
  default     = "LRS"
}

variable "storage_account_tier" {
  type        = string
  description = "Tier for the storage account"
  default     = "Standard"
}

variable "key_vault_sku_name" {
  type        = string
  description = "SKU name for the key vault"
  default     = "standard"
}

variable "search_service_sku_name" {
  type        = string
  description = "SKU name for the search service"
  default     = "free"
}

variable "search_service_sku_capacity" {
  type        = number
  description = "Capacity for the search service"
  default     = 1
}
variable "sample_file_path" {
  type = string
}

variable "search_service_partition_count" {
  description = "The number of partitions for the Azure Search Service."
  type        = number
  default     = 1
}

variable "content_filters" {
  type = map(object({
    mode           = string
    basePolicyName = string
    type           = string
    contentFilters = list(object({
      name                = string
      blocking            = bool
      enabled             = bool
      allowedContentLevel = string
      source              = string
    }))
  }))
  default = {
    "Block-High" = {
      mode           = "Default"
      basePolicyName = "Microsoft.Default"
      type           = "UserManaged"
      contentFilters = [
        { name = "Hate", blocking = true, enabled = true, allowedContentLevel = "High", source = "Prompt" },
        { name = "Sexual", blocking = true, enabled = true, allowedContentLevel = "High", source = "Prompt" },
        { name = "selfharm", blocking = true, enabled = true, allowedContentLevel = "High", source = "Prompt" },
        { name = "Violence", blocking = true, enabled = true, allowedContentLevel = "High", source = "Prompt" },
        { name = "Hate", blocking = true, enabled = true, allowedContentLevel = "High", source = "Completion" },
        { name = "Sexual", blocking = true, enabled = true, allowedContentLevel = "High", source = "Completion" },
        { name = "selfharm", blocking = true, enabled = true, allowedContentLevel = "High", source = "Completion" },
        { name = "Violence", blocking = true, enabled = true, allowedContentLevel = "High", source = "Completion" }
      ]
    },
    "Block-Medium" = {
      mode           = "Default"
      basePolicyName = "Microsoft.Default"
      type           = "UserManaged"
      contentFilters = [
        { name = "Hate", blocking = true, enabled = true, allowedContentLevel = "Medium", source = "Prompt" },
        { name = "Sexual", blocking = true, enabled = true, allowedContentLevel = "Medium", source = "Prompt" },
        { name = "selfharm", blocking = true, enabled = true, allowedContentLevel = "Medium", source = "Prompt" },
        { name = "Violence", blocking = true, enabled = true, allowedContentLevel = "Medium", source = "Prompt" },
        { name = "Hate", blocking = true, enabled = true, allowedContentLevel = "Medium", source = "Completion" },
        { name = "Sexual", blocking = true, enabled = true, allowedContentLevel = "Medium", source = "Completion" },
        { name = "selfharm", blocking = true, enabled = true, allowedContentLevel = "Medium", source = "Completion" },
        { name = "Violence", blocking = true, enabled = true, allowedContentLevel = "Medium", source = "Completion" }
      ]
    },
    "Block-Low" = {
      mode           = "Default"
      basePolicyName = "Microsoft.Default"
      type           = "UserManaged"
      contentFilters = [
        { name = "Hate", blocking = true, enabled = true, allowedContentLevel = "Low", source = "Prompt" },
        { name = "Sexual", blocking = true, enabled = true, allowedContentLevel = "Low", source = "Prompt" },
        { name = "selfharm", blocking = true, enabled = true, allowedContentLevel = "Low", source = "Prompt" },
        { name = "Violence", blocking = true, enabled = true, allowedContentLevel = "Low", source = "Prompt" },
        { name = "Hate", blocking = true, enabled = true, allowedContentLevel = "Low", source = "Completion" },
        { name = "Sexual", blocking = true, enabled = true, allowedContentLevel = "Low", source = "Completion" },
        { name = "selfharm", blocking = true, enabled = true, allowedContentLevel = "Low", source = "Completion" },
        { name = "Violence", blocking = true, enabled = true, allowedContentLevel = "Low", source = "Completion" }
      ]
    },

    "Allow-All" = {
      mode           = "Default"
      basePolicyName = "Microsoft.Default"
      type           = "UserManaged"
      contentFilters = []
    }
  }
}

variable "models" {
  type = map(object({
    model_format    = string
    model_name      = string
    model_version   = string
    rai_policy_name = string
    scale_type      = string
    scale_capacity  = number
  }))
  default = {
    "gpt-4o-mini-deployment" = {
      model_format    = "OpenAI"
      model_name      = "gpt-4o-mini"
      model_version   = "2024-07-18"
      rai_policy_name = "Block-High"
      scale_type      = "Standard"
      scale_capacity  = 8 // 8 requests per second, you must increase capacity for production.

    },
    "Dall-e-3" = {
      model_format    = "OpenAI"
      model_name      = "dall-e-3"
      model_version   = "3.0"
      rai_policy_name = "Allow-All"
      scale_type      = "Standard"
      scale_capacity  = 1
    },
    "gpt-35-turbo" = {
      model_format    = "OpenAI"
      model_name      = "gpt-35-turbo"
      model_version   = "0125"
      rai_policy_name = "Allow-All"
      scale_type      = "Standard"
      scale_capacity  = 30
    },
  }
}
