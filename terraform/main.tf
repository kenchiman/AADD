terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

provider "azuread" {
  tenant_id = "テナントID"
}

# Retrieve domain information
data "azuread_domains" "example" {
  only_initial = true
}

# Create an application
resource "azuread_application" "example" {
  display_name = "AAD DC Administrators"
}

resource "azurerm_resource_group" "example" {
  name     = "example-rg"
  location = "eastus"
}

resource "azurerm_virtual_network" "example" {
  name                = "aadds-vnet"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  address_space       = ["172.16.0.0/20"]

  dns_servers = ["172.16.0.5", "172.16.0.4"]
}

resource "azurerm_subnet" "aadds-subnet" {
  name                 = "aadds-subnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["172.16.0.0/24"]
}

resource "azurerm_network_security_group" "aadds-nsg" {
  name                = "aadds-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "AllowSyncWithAzureAD"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureActiveDirectoryDomainServices"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowPSRemoting"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5986"
    source_address_prefix      = "AzureActiveDirectoryDomainServices"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "addds" {
  subnet_id                 = azurerm_subnet.aadds-subnet.id
  network_security_group_id = azurerm_network_security_group.aadds-nsg.id
}

resource "azurerm_template_deployment" "aadds" {
  name                = "acctesttemplate01"
  resource_group_name = azurerm_resource_group.example.name
  template_body       = file("../arm/aadds.json")
  parameters = {
    apiVersion              = "2017-06-01"
    domainConfigurationType = "FullySynced"
    domainName              = "ドメイン名（任意名）"
    filteredSync            = "Disabled"
    location                = "eastus"
    subnetName              = "aadds-subnet"
    vnetName                = "aadds-vnet"
    vnetResourceGroup       = azurerm_resource_group.example.name
  }
  deployment_mode = "Incremental"
  depends_on      = [ azurerm_subnet.aadds-subnet ]
}