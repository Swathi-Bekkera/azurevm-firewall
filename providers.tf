terraform {
    required_version = ">=1.6.4"

    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = "3.70"
        }
        random = {
            source = "hashicorp/random"
            version = ">=3.0"
        }
   }
}
provider "azurerm" {
            features {}
            skip_provider_registration = true
}
resource "azurerm_resource_group" "fw" {
    name = "1-06271bd4-playground-sandbox"
    location = "southcentralus"
}