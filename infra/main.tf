terraform {
  required_version = ">= 1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  default = "swedencentral"
}

variable "image_tag" {
  default = "latest"
}

resource "azurerm_resource_group" "main" {
  name     = "insurance-devops-rg"
  location = var.location
}

# Azure Container Registry — przechowuje obrazy Docker
resource "azurerm_container_registry" "main" {
  name                = "insurancedevopsacr"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
}

# Log Analytics — backend dla monitoringu
resource "azurerm_log_analytics_workspace" "main" {
  name                = "insurance-devops-law"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Storage Account — przechowuje dataset
resource "azurerm_storage_account" "main" {
  name                     = "insurancedevopssa"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public  = false
  cross_tenant_replication_enabled = false
}

# Container Apps Environment
resource "azurerm_container_app_environment" "main" {
  name                       = "insurance-devops-env"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

# Managed Identity dla Container App
resource "azurerm_user_assigned_identity" "api" {
  name                = "insurance-devops-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
}

# Rola AcrPull — pozwala Managed Identity pobierać obrazy z ACR
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# Rola Storage Blob Data Reader — pozwala Managed Identity czytać pliki z Blob Storage
resource "azurerm_role_assignment" "blob_reader" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_user_assigned_identity.api.principal_id
}

# Container App — uruchamia mikroserwis
resource "azurerm_container_app" "api" {
  name                         = "insurance-api"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.api.id]
  }

  registry {
    server   = azurerm_container_registry.main.login_server
    identity = azurerm_user_assigned_identity.api.id
  }

  template {
    container {
      name   = "insurance-api"
      image  = "${azurerm_container_registry.main.login_server}/insurance-api:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "AZURE_CLIENT_ID"
        value = azurerm_user_assigned_identity.api.client_id
      }

      env {
        name  = "STORAGE_ACCOUNT_URL"
        value = azurerm_storage_account.main.primary_blob_endpoint
      }

      env {
        name  = "BLOB_CONTAINER"
        value = "dataset"
      }

      env {
        name  = "BLOB_NAME"
        value = "dataset.csv"
      }

      liveness_probe {
        transport = "HTTP"
        path      = "/health"
        port      = 80
      }
    }

    min_replicas = 1
    max_replicas = 5
  }

  ingress {
    external_enabled = true
    target_port      = 80
    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }
}

output "api_url" {
  value = "https://${azurerm_container_app.api.latest_revision_fqdn}"
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}
