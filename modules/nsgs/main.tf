resource "azurerm_network_security_group" "xipper-nsg" {
  name                = var.public_nsg_name
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "frontendinbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.load_balancer_ip
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow-frontend-to-backend"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.144.0/20"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "allow-bastion-to-public1"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.32.0/26" # AzureBastionSubnet
    destination_address_prefix = "*"            # public1 subnet
  }

  # security_rule {
  #   name                       = "outboundforloadbalancer"
  #   priority                   = 201
  #   direction                  = "Outbound"
  #   access                     = "Allow"
  #   protocol                   = "*"
  #   source_port_range          = "*"
  #   destination_port_range     = "*"
  #   source_address_prefix      = "*"
  #   destination_address_prefix = var.load_balancer_ip
  # }
  security_rule {
    name                       = "publicweboutbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate the NSG with the public1 subnet
resource "azurerm_subnet_network_security_group_association" "public1_nsg_association" {
  # subnet_id = var.subnet_ids[0]
  subnet_id                 = element(var.subnet_ids, 0)
  network_security_group_id = azurerm_network_security_group.xipper-nsg.id
}

# Associate the NSG with the public2 subnet
# resource "azurerm_subnet_network_security_group_association" "public2_nsg_association" {
#   # subnet_id = var.subnet_ids[1]
#   subnet_id                 = element(var.subnet_ids, 1)
#   network_security_group_id = azurerm_network_security_group.xipper-nsg.id
# }
