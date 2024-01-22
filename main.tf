resource "random_id" "uniqueid" {
  byte_length = 4
}

resource "random_string" "string" {
  length           = 5
  special          = false
  lower            = true
  upper            = false
}

resource "random_password" "admin_password" {
    length = 6
    special = true
    override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_network_security_group" "nsg1" {
    name = "nsg_${azurerm_virtual_network.vnet.name}"
    resource_group_name = azurerm_resource_group.fw.name
    location = azurerm_resource_group.fw.location
    security_rule {
        name = "rule1-${azurerm_virtual_network.vnet.name}"
        priority = 100
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "22"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_virtual_network" "vnet" {
    name = "vnet_${random_string.string.result}"
    resource_group_name = azurerm_resource_group.fw.name
    location = azurerm_resource_group.fw.location
    address_space = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
        name = "subnet_${random_string.string.result}"
        resource_group_name = azurerm_resource_group.fw.name
        virtual_network_name = azurerm_virtual_network.vnet.name
        address_prefixes = ["10.0.1.0/24"]
}

resource "azurerm_storage_account" "new_storage_account" {
    name = "storage${random_string.string.result}"
    resource_group_name = azurerm_resource_group.fw.name
    location = azurerm_resource_group.fw.location
    account_tier = "Standard"
    account_replication_type = "LRS"
}

resource "azurerm_public_ip" "pip" {
    name = "pip_${random_string.string.result}"
    resource_group_name = azurerm_resource_group.fw.name
    location = azurerm_resource_group.fw.location
    allocation_method = "Dynamic"
}

resource "azurerm_network_interface" "mynic" {
    name = "NIC_${random_string.string.result}"
    location = azurerm_resource_group.fw.location
    resource_group_name = azurerm_resource_group.fw.name

    ip_configuration {
        name = "NICconfig_${random_string.string.result}"
        private_ip_address_allocation = "Dynamic"
        subnet_id = azurerm_subnet.subnet.id
        public_ip_address_id = azurerm_public_ip.pip.id

    }
}

resource "azurerm_network_interface_security_group_association" "association" {
    network_interface_id = azurerm_network_interface.mynic.id
    network_security_group_id = azurerm_network_security_group.nsg1.id
}

resource "azurerm_linux_virtual_machine" "vm" {
    name = "vm_${random_string.string.result}"
    resource_group_name = azurerm_resource_group.fw.name
    location = azurerm_resource_group.fw.location
    size = "Standard_DS1_v2"
    computer_name = "hostname"
    admin_username = var.admin_username
    admin_password = random_password.admin_password.result
    disable_password_authentication = "false"
    network_interface_ids = [azurerm_network_interface.mynic.id]

    os_disk {
        name = "os_disk_${random_string.string.result}"
        caching = "ReadWrite"
        storage_account_type = "Standard_LRS"   
    }

    source_image_reference {
        publisher = "Canonical"
        offer = "0001-com-ubuntu-server-jammy"
        sku = "22_04-lts-gen2"
        version   = "latest"
    }
}

resource "azurerm_ip_group" "workload_ip_group" {
  name                = "workload-ip-group"
  resource_group_name = azurerm_resource_group.fw.name
  location            = azurerm_resource_group.fw.location
  cidrs               = ["10.20.0.0/24", "10.30.0.0/24"]
}
resource "azurerm_ip_group" "infra_ip_group" {
  name                = "infra-ip-group"
  resource_group_name = azurerm_resource_group.fw.name
  location            = azurerm_resource_group.fw.location
  cidrs               = ["10.40.0.0/24", "10.50.0.0/24"]
}

resource "azurerm_subnet" "azfw_subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.fw.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/26"]
}

resource "azurerm_subnet" "firewall-mgmt" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = azurerm_resource_group.fw.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes      = ["10.0.3.0/24"]
}

resource "azurerm_public_ip" "pip_azfw" {
  name                = "pip-azfw"
  location            = azurerm_resource_group.fw.location
  resource_group_name = azurerm_resource_group.fw.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "firewall-mgmt" {
  name                = "fw-mgmt"
  location            = azurerm_resource_group.fw.location
  resource_group_name = azurerm_resource_group.fw.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall_policy" "azfw_policy" {
  name                     = "azfw-policy"
  resource_group_name      = azurerm_resource_group.fw.name
  location                 = azurerm_resource_group.fw.location
  sku                      = "Standard"
  threat_intelligence_mode = "Alert"
}

resource "azurerm_firewall_policy_rule_collection_group" "net_policy_rule_collection_group" {
  name               = "DefaultNetworkRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.azfw_policy.id
  priority           = 200
  network_rule_collection {
    name     = "DefaultNetworkRuleCollection"
    action   = "Allow"
    priority = 200
    rule {
      name                  = "time-windows"
      protocols             = ["UDP"]
      source_ip_groups      = [azurerm_ip_group.workload_ip_group.id, azurerm_ip_group.infra_ip_group.id]
      destination_ports     = ["123"]
      destination_addresses = ["132.86.101.172"]
    }
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "app_policy_rule_collection_group" {
  name               = "DefaulApplicationtRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.azfw_policy.id
  priority           = 300
  application_rule_collection {
    name     = "DefaultApplicationRuleCollection"
    action   = "Allow"
    priority = 500
    rule {
      name = "AllowWindowsUpdate"

      description = "Allow Windows Update"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_ip_groups      = [azurerm_ip_group.workload_ip_group.id, azurerm_ip_group.infra_ip_group.id]
      destination_fqdn_tags = ["WindowsUpdate"]
    }
    rule {
      name        = "Global Rule"
      description = "Allow access to Microsoft.com"
      protocols {
        type = "Https"
        port = 443
      }
      destination_fqdns = ["*.microsoft.com"]
      terminate_tls     = false
      source_ip_groups  = [azurerm_ip_group.workload_ip_group.id, azurerm_ip_group.infra_ip_group.id]
    }
  }
}

resource "azurerm_firewall" "fw" {
  name                = "azfw"
  location            = azurerm_resource_group.fw.location
  resource_group_name = azurerm_resource_group.fw.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"
  ip_configuration {
    name                 = "azfw-ipconfig"
    subnet_id            = azurerm_subnet.azfw_subnet.id
    public_ip_address_id = azurerm_public_ip.pip_azfw.id
  }
  firewall_policy_id = azurerm_firewall_policy.azfw_policy.id

  management_ip_configuration {
    name                 = "management"
    subnet_id            = azurerm_subnet.firewall-mgmt.id
    public_ip_address_id = azurerm_public_ip.firewall-mgmt.id
  }
}