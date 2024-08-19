resource "azurerm_network_security_group" "xipper-private-nsg" {
  name                = var.private_nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowInternalTraffic"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.144.0/20" // Allow traffic from within the VNet
    destination_address_prefix = "*"             // Adjust based on your subnet's address space
  }
  # security_rule {
  #   name                       = "AllowInternalTraffic2"
  #   priority                   = 101
  #   direction                  = "Inbound"
  #   access                     = "Allow"
  #   protocol                   = "*"
  #   source_port_range          = "*"
  #   destination_port_range     = "*"
  #   source_address_prefix      = var.vnet_address_space[0]
  #   destination_address_prefix = "10.0.144.0/20"
  # }
  security_rule {
    name                       = "allow-bastion-to-private1"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.32.0/26" # AzureBastionSubnet
    destination_address_prefix = "*"            # private1 subnet
  }

  security_rule {
    name                       = "AllowInternalOutbound"
    priority                   = 101
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.128.0/20" // Source subnet
    destination_address_prefix = "0.0.0.0/0"     // Allow traffic to the entire VNet
  }
}

resource "azurerm_subnet_network_security_group_association" "private1_nsg_association" {
  # subnet_id = var.subnet_ids[0]
  subnet_id                 = element(var.private_subnet_ids, 0)
  network_security_group_id = azurerm_network_security_group.xipper-private-nsg.id
}

# resource "azurerm_subnet_network_security_group_association" "private2_nsg_association" {
#   # subnet_id = var.subnet_ids[1]
#   subnet_id                 = element(var.subnet_ids, 1)
#   network_security_group_id = azurerm_network_security_group.xipper-private-nsg.id
# }


