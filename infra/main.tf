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

locals {
  prefix = "insurance-devops"
}

resource "azurerm_resource_group" "main" {
  name     = "${local.prefix}-rg"
  location = var.location
}

# Azure Container Registry — przechowuje obrazy Docker
resource "azurerm_container_registry" "main" {
  name                = replace("${local.prefix}acr", "-", "")
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Log Analytics — backend dla monitoringu
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${local.prefix}-law"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Container Apps Environment
resource "azurerm_container_app_environment" "main" {
  name                       = "${local.prefix}-env"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

# Container App — uruchamia mikroserwis
resource "azurerm_container_app" "api" {
  name                         = "insurance-api"
  resource_group_name          = azurerm_resource_group.main.name
  container_app_environment_id = azurerm_container_app_environment.main.id
  revision_mode                = "Single"

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  template {
    container {
      name   = "insurance-api"
      image  = "${azurerm_container_registry.main.login_server}/insurance-api:latest"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "DATA_PATH"
        value = "dataset/customer_training_dataset.csv"
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
