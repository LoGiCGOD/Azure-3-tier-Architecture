resource "azurerm_virtual_network" "xipper-vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space

  subnet {
    name           = "public1"
    address_prefix = "10.0.0.0/20"
  }

  # subnet {
  #   name           = "public2"
  #   address_prefix = "10.0.16.0/20"
  # }
  subnet {
    name           = "private1"
    address_prefix = "10.0.128.0/20"
  }
  subnet {
    name           = "private2"
    address_prefix = "10.0.144.0/20"
  }
  subnet {
    name           = "private3"
    address_prefix = "10.0.160.0/20"
  }

}
