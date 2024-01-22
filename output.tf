output "virtual_machine_name" {
  value = azurerm_linux_virtual_machine.vm.name
}

output "public_ip_address_of_vm" {
  value = "azurerm_linux_virtual_machine.vm.public_ip_address"
}

output "fw_name" {
    value = "azurerm_firewall.fw.name"
}

output "public_ip_fw" {
    value = "azurerm_public_ip.pip_azfw.id"
}