resource "azurerm_network_interface" "public_nic" {
  name                = "${var.public_vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.public_subnet_id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_network_interface" "private_nic" {
  name                = "${var.private_vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.private_subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "public_vm" {
  name                  = var.public_vm_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.public_nic.id]
  vm_size               = "Standard_DS1_v2"
  zones                 = ["1"]
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.public_vm_name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = var.public_vm_name
    admin_username = "xipper"
    admin_password = "xipper@2024"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  delete_os_disk_on_termination = true
}

resource "azurerm_virtual_machine" "private_vm" {
  name                  = var.private_vm_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.private_nic.id]
  vm_size               = "Standard_DS1_v2"
  zones                 = ["1"]
  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.private_vm_name}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = var.private_vm_name
    admin_username = "xipper"
    admin_password = "xipper@2024"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
  delete_os_disk_on_termination = true
}

# resource "azurerm_public_ip" "public_ip" {
#   name                = "public-ip"
#   location            = var.location
#   resource_group_name = var.resource_group_name
#   allocation_method   = "Dynamic"
# }

