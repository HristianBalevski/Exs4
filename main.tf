terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.25.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "00ef8380-3847-4ec6-9d08-9d9a47ee71c0"
}

resource "random_integer" "priority" {
  min = 10000
  max = 99999
}

resource "azurerm_resource_group" "azure_resource_group" {
  name     = "${var.resource_group_name}-${random_integer.priority.result}"
  location = var.resource_group_location
}

resource "azurerm_service_plan" "Azure-Service-Plan" {
  name                = "${var.app_service_plan_name}-${random_integer.priority.result}"
  resource_group_name = azurerm_resource_group.azure_resource_group.name
  location            = azurerm_resource_group.azure_resource_group.location
  os_type             = "Linux"
  sku_name            = "F1"
}

resource "azurerm_linux_web_app" "Azure-Linux-Web-App" {
  name                = "${var.app_service_name}-${random_integer.priority.result}"
  resource_group_name = azurerm_resource_group.azure_resource_group.name
  location            = azurerm_resource_group.azure_resource_group.location
  service_plan_id     = azurerm_service_plan.Azure-Service-Plan.id

  site_config {
    application_stack {
      dotnet_version = "6.0"
    }
    always_on = false
  }

  connection_string {
    name  = "DefaultConnection"
    type  = "SQLAzure"
    value = "Data Source=tcp:${azurerm_mssql_server.sqlserver.fully_qualified_domain_name},1433;Initial Catalog=${azurerm_mssql_database.database.name};User ID=${azurerm_mssql_server.sqlserver.administrator_login};Password=${azurerm_mssql_server.sqlserver.administrator_login_password};Trusted_Connection=False; MultipleActiveResultSets=True;"
  }
}

resource "azurerm_mssql_server" "sqlserver" {
  name                         = "${var.sql_server_name}-${random_integer.priority.result}"
  resource_group_name          = azurerm_resource_group.azure_resource_group.name
  location                     = azurerm_resource_group.azure_resource_group.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password

}

resource "azurerm_mssql_database" "database" {
  name                 = "${var.sql_database_name}-${random_integer.priority.result}"
  server_id            = azurerm_mssql_server.sqlserver.id
  collation            = "SQL_Latin1_General_CP1_CI_AS"
  license_type         = "LicenseIncluded"
  max_size_gb          = 2
  sku_name             = "S0"
  zone_redundant       = false
  storage_account_type = "Zone"
  geo_backup_enabled   = false
}

resource "azurerm_mssql_firewall_rule" "firewall" {
  name             = var.firewall_rule_name
  server_id        = azurerm_mssql_server.sqlserver.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_app_service_source_control" "Azure-Source-Control" {
  app_id                 = azurerm_linux_web_app.Azure-Linux-Web-App.id
  repo_url               = var.repo_URL
  branch                 = "main"
  use_manual_integration = true
}