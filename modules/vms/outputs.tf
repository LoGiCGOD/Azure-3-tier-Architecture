output "public_vm_id" {
  description = "The ID of the public VM"
  value       = azurerm_virtual_machine.public_vm.id
}

output "private_vm_id" {
  description = "The ID of the private VM"
  value       = azurerm_virtual_machine.private_vm.id
}

output "public_ip" {
  description = "The public IP address of the public VM"
  value       = azurerm_public_ip.public_ip.ip_address
}
