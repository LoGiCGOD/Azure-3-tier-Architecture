output "vnet_name" {
  description = "name of the virtual netork"
  value       = azurerm_virtual_network.xipper-vnet.name
}

output "vnet_address_space" {
  description = "Vnet address"
  value       = azurerm_virtual_network.xipper-vnet.address_space
}

output "vnet_id" {
  description = "id of the virtual network"
  value       = azurerm_virtual_network.xipper-vnet.id
}

# output "subnet_ids" {
#   description = "List of subnet IDs"
#   value       = azurerm_virtual_network.xipper-vnet.subnet[*].id
# }

output "subnet_ids" {
  description = "List of subnet IDs"
  value       = [for subnet in azurerm_virtual_network.xipper-vnet.subnet : subnet.id]
}


output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = [for subnet in azurerm_virtual_network.xipper-vnet.subnet : subnet.id if subnet.name == "public1"]
  # value       = [for subnet in azurerm_virtual_network.xipper-vnet.subnet : subnet.id if subnet.name == "public1" || subnet.name == "public2"]
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = [for subnet in azurerm_virtual_network.xipper-vnet.subnet : subnet.id if subnet.name == "private1"]
  # value       = [for subnet in azurerm_virtual_network.xipper-vnet.subnet : subnet.id if subnet.name == "private1" || subnet.name == "private2"]
}

