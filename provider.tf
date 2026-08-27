terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  cloud {
    organization = "ninad-terraform-lab"

    workspaces {
      name = "terraform-ansible-azure"
    }
  }
}

provider "azurerm" {
  features {}
}
