terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }

  # Uncomment and configure to store state in Azure Storage
  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate"
  #   storage_account_name = "tfstatedemo"
  #   container_name       = "tfstate"
  #   key                  = "user1/terraform.tfstate"
  # }
}

provider "azurerm" {
  features {}
}

module "windows_vm" {
  source = "../../modules/windows-vm"

  resource_group_name = var.resource_group_name
  location            = var.location
  vm_name             = var.vm_name
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
}
