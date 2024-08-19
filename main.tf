resource "azurerm_resource_group" "xipper" {
  name     = var.resource_group_name
  location = var.location
}

module "vnet" {
  source              = "./modules/vnet"
  resource_group_name = azurerm_resource_group.xipper.name
  location            = azurerm_resource_group.xipper.location
  vnet_name           = var.vnet_name
  vnet_address_space  = var.vnet_address_space

}

module "nsgs" {
  source              = "./modules/nsgs"
  resource_group_name = azurerm_resource_group.xipper.name
  location            = azurerm_resource_group.xipper.location
  vnet_name           = module.vnet.vnet_name
  public_nsg_name     = var.public_nsg_name
  subnet_ids          = module.vnet.public_subnet_ids //comes from vnet/outputs.tf
  vnet_address_space  = module.vnet.vnet_address_space
  load_balancer_ip    = azurerm_public_ip.loadbalancer-publicIP.ip_address
}


module "pvt-nsgs" {
  source              = "./modules/pvt-nsgs"
  resource_group_name = azurerm_resource_group.xipper.name
  location            = azurerm_resource_group.xipper.location
  vnet_address_space  = module.vnet.vnet_address_space
  private_nsg_name    = var.private_nsg_name
  private_subnet_ids  = module.vnet.private_subnet_ids
}

# module "vms" {
#   source              = "./modules/vms"
#   resource_group_name = var.resource_group_name
#   location            = var.location
#   public_subnet_id    = element(module.vnet.public_subnet_ids, 0)
#   private_subnet_id   = element(module.vnet.private_subnet_ids, 0)
#   public_vm_name      = var.public_vm_name
#   private_vm_name     = var.private_vm_name
# }



// NAT Gateway setup
resource "azurerm_public_ip" "nat_gateway_public_ip" {
  name                = "nat-gateway-public-ip"
  location            = azurerm_resource_group.xipper.location
  resource_group_name = azurerm_resource_group.xipper.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

resource "azurerm_nat_gateway" "nat_gateway" {
  name                = "nat-gateway"
  location            = azurerm_resource_group.xipper.location
  resource_group_name = azurerm_resource_group.xipper.name

  sku_name = "Standard"
  zones    = ["1"]

}

locals {
  private_subnet_ids = module.vnet.private_subnet_ids
  subnet_ids_map     = { for idx, subnet_id in local.private_subnet_ids : idx => subnet_id }
}

resource "azurerm_subnet_nat_gateway_association" "nat_gateway_association" {
  for_each  = local.subnet_ids_map
  subnet_id = each.value
  # subnet_id      = element(module.vnet.private_subnet_ids, 0) // Assuming private subnet ID
  nat_gateway_id = azurerm_nat_gateway.nat_gateway.id
}

resource "azurerm_route_table" "private_subnet_route_table" {
  name                = "private-subnet-route-table"
  location            = azurerm_resource_group.xipper.location
  resource_group_name = azurerm_resource_group.xipper.name

  route {
    name           = "route-to-nat-gateway"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
    # next_hop_in_ip_address = azurerm_public_ip.nat_gateway_public_ip.ip_address

  }
}

resource "azurerm_subnet_route_table_association" "private_subnet_route_association" {
  for_each       = local.subnet_ids_map
  subnet_id      = each.value
  route_table_id = azurerm_route_table.private_subnet_route_table.id
}

resource "azurerm_nat_gateway_public_ip_association" "nat_ip_association" {
  nat_gateway_id       = azurerm_nat_gateway.nat_gateway.id
  public_ip_address_id = azurerm_public_ip.nat_gateway_public_ip.id
}

#VMSS
resource "azurerm_linux_virtual_machine_scale_set" "xipper-vmss" {
  name                = "xipper-vmss"
  resource_group_name = azurerm_resource_group.xipper.name
  location            = azurerm_resource_group.xipper.location
  sku                 = "Standard_B2s_v2"

  instances      = 1
  admin_username = "xipper"

  admin_password = "Xipper@2024"
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
  disable_password_authentication = false
  computer_name_prefix            = var.public_vm_name
  zone_balance                    = true
  zones                           = ["2", "3"]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS" // Choose based on your performance needs

  }

  network_interface {
    name    = "public-network-interface"
    primary = true

    ip_configuration {
      name = "xipper-vmss-ipconfig"

      primary   = true
      subnet_id = element(module.vnet.public_subnet_ids, 0)
      # load_balancer_backend_address_pool_ids = [for pool in azurerm_application_gateway.xipper-app-gateway.backend_address_pool : pool.id]
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.frontend-pool.id]

    }
  }
}


resource "azurerm_monitor_autoscale_setting" "monitor-scale" {
  name                = "monitor-vmss"
  resource_group_name = azurerm_resource_group.xipper.name
  location            = azurerm_resource_group.xipper.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.xipper-vmss.id

  profile {
    name = "defaultProfile"
    capacity {
      minimum = "1"
      maximum = "2"
      default = "1"
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.xipper-vmss.id
        operator           = "GreaterThan"
        statistic          = "Average"
        threshold          = 70
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT3M"
        dimensions {
          name     = "ScaledVM"
          operator = "Equals"
          values   = ["ScaledApp1"]
        }
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.xipper-vmss.id
        operator           = "LessThan"
        statistic          = "Average"
        threshold          = 45
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}


#Load-Balancer
resource "azurerm_public_ip" "loadbalancer-publicIP" {
  name                = "loadbalancer-publicIP"
  resource_group_name = azurerm_resource_group.xipper.name
  location            = azurerm_resource_group.xipper.location
  allocation_method   = "Static"
  sku                 = "Standard"
}


resource "azurerm_lb" "frontend-lb" {
  name                = "FrontendLoadBalancer"
  resource_group_name = azurerm_resource_group.xipper.name
  location            = azurerm_resource_group.xipper.location
  sku                 = "Standard"
  frontend_ip_configuration {
    name = "PublicIPAddress"
    # subnet_id                     = element(module.vnet.public_subnet_ids, 1)
    # private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.loadbalancer-publicIP.id
  }

}

resource "azurerm_lb_probe" "frontend-probe" {
  loadbalancer_id     = azurerm_lb.frontend-lb.id
  name                = "frontend-lb-probe"
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_backend_address_pool" "frontend-pool" {
  loadbalancer_id = azurerm_lb.frontend-lb.id
  name            = "FrontendAddressPool"
}

resource "azurerm_lb_rule" "frontend-lb-rule" {
  loadbalancer_id                = azurerm_lb.frontend-lb.id
  name                           = "Frontend-LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = azurerm_lb_probe.frontend-probe.id
}


#VMSS for Private Subnet
resource "azurerm_linux_virtual_machine_scale_set" "xipper-private-vmss" {
  name                = "xipper-private-vmss"
  resource_group_name = azurerm_resource_group.xipper.name
  location            = azurerm_resource_group.xipper.location
  sku                 = "Standard_B2s_v2"

  instances      = 1
  admin_username = "xipper"
  admin_password = "Xipper@2024"
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
  disable_password_authentication = false
  computer_name_prefix            = var.private_vm_name
  zone_balance                    = true
  zones                           = ["2", "3"]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"

  }

  network_interface {
    name    = "private-network-interface"
    primary = true

    ip_configuration {
      name = "xipper-private-vmss-ipconfig"

      primary   = true
      subnet_id = element(module.vnet.private_subnet_ids, 0)
      # load_balancer_backend_address_pool_ids = [for pool in azurerm_application_gateway.xipper-private-app-gateway.backend_address_pool : pool.id]
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.backend-pool.id]
    }
  }
}


resource "azurerm_monitor_autoscale_setting" "monitor-private-scale" {
  name                = "monitor-private-vmss"
  resource_group_name = azurerm_resource_group.xipper.name
  location            = azurerm_resource_group.xipper.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.xipper-private-vmss.id

  profile {
    name = "Xipper-Private-Profile"
    capacity {
      minimum = "1"
      maximum = "2"
      default = "1"
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.xipper-private-vmss.id
        operator           = "GreaterThan"
        statistic          = "Average"
        threshold          = 70
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT3M"
        dimensions {
          name     = "BackendScaledVM"
          operator = "Equals"
          values   = ["BackendScaledApp"]
        }
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.xipper-private-vmss.id
        operator           = "LessThan"
        statistic          = "Average"
        threshold          = 45
        time_aggregation   = "Average"
        time_grain         = "PT1M"
        time_window        = "PT5M"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }

}

#Backend-LoadBalancer
resource "azurerm_lb" "backend-lb" {
  name                = "BackendLoadBalancer"
  resource_group_name = azurerm_resource_group.xipper.name
  location            = azurerm_resource_group.xipper.location
  sku                 = "Standard"
  frontend_ip_configuration {
    name                          = "InternalIPAddress"
    subnet_id                     = module.vnet.subnet_ids[2]
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_lb_probe" "backend-probe" {
  loadbalancer_id     = azurerm_lb.backend-lb.id
  name                = "backend-lb-probe"
  protocol            = "Http"
  port                = 80
  request_path        = "/"
  interval_in_seconds = 5
  number_of_probes    = 2
}

resource "azurerm_lb_backend_address_pool" "backend-pool" {
  loadbalancer_id = azurerm_lb.backend-lb.id
  name            = "BackendAddressPool"
}

resource "azurerm_lb_rule" "backend-lb-rule" {
  loadbalancer_id                = azurerm_lb.backend-lb.id
  name                           = "Backend-LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "InternalIPAddress"
  probe_id                       = azurerm_lb_probe.backend-probe.id
}


# Bastion-Host
resource "azurerm_subnet" "bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.xipper.name
  virtual_network_name = module.vnet.vnet_name
  address_prefixes     = ["10.0.32.0/26"]
}



resource "azurerm_public_ip" "bastion_public_ip" {
  name                = "bastion-public-ip"
  location            = azurerm_resource_group.xipper.location
  resource_group_name = azurerm_resource_group.xipper.name
  allocation_method   = "Static"
  sku                 = "Standard"
}


resource "azurerm_bastion_host" "bastion" {
  name                = "xipper-bastion"
  location            = azurerm_resource_group.xipper.location
  resource_group_name = azurerm_resource_group.xipper.name

  # dns_name = "bastion-${var.location}.azure.com"
  sku = "Standard"

  ip_configuration {
    name                 = "bastion-configuration"
    subnet_id            = azurerm_subnet.bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.bastion_public_ip.id
  }
}







# locals {
#   backend_address_pool_name      = "${module.vnet.vnet_name}-beap"
#   frontend_port_name             = "${module.vnet.vnet_name}-feport"
#   frontend_ip_configuration_name = "${module.vnet.vnet_name}-feip"
#   http_setting_name              = "${module.vnet.vnet_name}-be-htst"
#   listener_name                  = "${module.vnet.vnet_name}-httplstn"
#   request_routing_rule_name      = "${module.vnet.vnet_name}-rqrt"
#   redirect_configuration_name    = "${module.vnet.vnet_name}-rdrcfg"
# }



# resource "azurerm_application_gateway" "xipper-app-gateway" {
#   depends_on = [
#     azurerm_resource_group.xipper,
#     module.vnet

#   ]
#   name                = "xipper-frontend-gateway"
#   resource_group_name = azurerm_resource_group.xipper.name
#   location            = azurerm_resource_group.xipper.location
#   sku {
#     name = "Standard_v2"
#     tier = "Standard_v2"
#   }

#   autoscale_configuration {
#     min_capacity = 1
#     max_capacity = 2
#   }

#   gateway_ip_configuration {
#     name      = "xipper-gateway-ip"
#     subnet_id = module.vnet.subnet_ids[1]
#   }

#   frontend_ip_configuration {
#     name                 = "loadbalancer-publicIP"
#     public_ip_address_id = azurerm_public_ip.loadbalancer-publicIP.id
#   }


#   frontend_port {
#     name = "http"
#     port = 80
#   }

#   http_listener {
#     name                           = local.listener_name
#     frontend_ip_configuration_name = "loadbalancer-publicIP"
#     frontend_port_name             = "http"
#     protocol                       = "Http"
#   }

#   backend_http_settings {
#     name                  = "front-loadbalancer-backend-settings"
#     cookie_based_affinity = "Disabled"
#     port                  = 80
#     protocol              = "Http"
#     request_timeout       = 20
#   }

#   backend_address_pool {
#     name = local.backend_address_pool_name

#   }

#   request_routing_rule {
#     name                       = local.request_routing_rule_name
#     rule_type                  = "Basic"
#     priority                   = 1
#     http_listener_name         = local.listener_name
#     backend_address_pool_name  = local.backend_address_pool_name
#     backend_http_settings_name = "front-loadbalancer-backend-settings"
#   }
# }




#VMSS for Private Subnet
# resource "azurerm_linux_virtual_machine_scale_set" "xipper-private-vmss" {
#   name                = "xipper-vmss"
#   resource_group_name = azurerm_resource_group.xipper.name
#   location            = azurerm_resource_group.xipper.location
#   sku                 = "Standard_DS1_v2"

#   instances      = 1
#   admin_username = "xipper"
#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "UbuntuServer"
#     sku       = "18.04-LTS"
#     version   = "latest"
#   }
#   disable_password_authentication = true
#   computer_name_prefix            = var.private_vm_name
#   zone_balance                    = true
#   zones                           = ["1", "2"]

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"

#   }

#   network_interface {
#     name    = "private-network-interface"
#     primary = true

#     ip_configuration {
#       name = "xipper-private-vmss-ipconfig"

#       primary                                = true
#       subnet_id                              = element(module.vnet.private_subnet_ids, 0)
#       load_balancer_backend_address_pool_ids = [for pool in azurerm_application_gateway.xipper-private-app-gateway.backend_address_pool : pool.id]
#     }
#   }
# }


# resource "azurerm_monitor_autoscale_setting" "monitor-private-scale" {
#   name                = "monitor-private-vmss"
#   resource_group_name = azurerm_resource_group.xipper.name
#   location            = azurerm_resource_group.xipper.location
#   target_resource_id  = azurerm_linux_virtual_machine_scale_set.xipper-private-vmss.id

#   profile {
#     name = "Xipper-Private-Profile"
#     capacity {
#       minimum = "1"
#       maximum = "2"
#       default = "1"
#     }

#     rule {
#       metric_trigger {
#         metric_name        = "Percentage CPU"
#         metric_resource_id = azurerm_linux_virtual_machine_scale_set.xipper-private-vmss.id
#         operator           = "GreaterThan"
#         statistic          = "Average"
#         threshold          = 70
#         time_aggregation   = "Average"
#         time_grain         = "PT1M"
#         time_window        = "PT5M"
#       }

#       scale_action {
#         direction = "Increase"
#         type      = "ChangeCount"
#         value     = "1"
#         cooldown  = "PT1M"
#       }
#     }

#     rule {
#       metric_trigger {
#         metric_name        = "Percentage CPU"
#         metric_resource_id = azurerm_linux_virtual_machine_scale_set.xipper-private-vmss.id
#         operator           = "LessThan"
#         statistic          = "Average"
#         threshold          = 45
#         time_aggregation   = "Average"
#         time_grain         = "PT1M"
#         time_window        = "PT5M"
#       }

#       scale_action {
#         direction = "Decrease"
#         type      = "ChangeCount"
#         value     = "1"
#         cooldown  = "PT1M"
#       }
#     }
#   }
#   notification {
#     email {
#       send_to_subscription_administrator    = true
#       send_to_subscription_co_administrator = true
#     }
#   }
# }


# #LoadBalancer for private subnets
# resource "azurerm_public_ip" "backend-publicIP" {
#   name                = "backend-loadbalancer-publicIP"
#   resource_group_name = azurerm_resource_group.xipper.name
#   location            = azurerm_resource_group.xipper.location
#   allocation_method   = "Static"
#   sku                 = "Standard"
# }

# locals {
#   backend_address_pool_name1      = "${module.vnet.vnet_name}-private-beap"
#   frontend_port_name1             = "${module.vnet.vnet_name}-private-feport"
#   frontend_ip_configuration_name1 = "${module.vnet.vnet_name}-private-feip"
#   http_setting_name1              = "${module.vnet.vnet_name}-private-be-htst"
#   listener_name1                  = "${module.vnet.vnet_name}-private-httplstn"
#   request_routing_rule_name1      = "${module.vnet.vnet_name}-private-rqrt"
#   redirect_configuration_name1    = "${module.vnet.vnet_name}-private-rdrcfg"
# }



# resource "azurerm_application_gateway" "xipper-private-app-gateway" {
#   depends_on = [
#     azurerm_resource_group.xipper,
#     module.vnet

#   ]
#   name                = "xipper-backend-gateway"
#   resource_group_name = azurerm_resource_group.xipper.name
#   location            = azurerm_resource_group.xipper.location
#   sku {
#     name = "Standard_v2"
#     tier = "Standard_v2"
#   }

#   autoscale_configuration {
#     min_capacity = 1
#     max_capacity = 2
#   }

#   gateway_ip_configuration {
#     name      = "xipper-backend-gateway-ip"
#     subnet_id = module.vnet.subnet_ids[3]
#   }

#   frontend_ip_configuration {
#     name = "backend-loadbalancer-privateIP"
#     # private_ip_address_allocation = "Static"
#     public_ip_address_id = azurerm_public_ip.backend-publicIP.id
#   }


#   frontend_port {
#     name = local.frontend_port_name1
#     port = 3000 //application gateway is listening on
#   }

#   http_listener {
#     name                           = "backend-lb-listener"
#     frontend_ip_configuration_name = "backend-loadbalancer-privateIP"
#     frontend_port_name             = local.frontend_port_name1
#     protocol                       = "Http"
#   }

#   backend_http_settings {
#     name                  = "front-loadbalancer-backend-settings"
#     cookie_based_affinity = "Disabled"
#     port                  = 5000
#     protocol              = "Http"
#     request_timeout       = 20
#   }

#   backend_address_pool {
#     name = local.backend_address_pool_name1

#   }

#   request_routing_rule {
#     name                       = local.request_routing_rule_name1
#     rule_type                  = "Basic"
#     priority                   = 2
#     http_listener_name         = "backend-lb-listener"
#     backend_address_pool_name  = local.backend_address_pool_name1
#     backend_http_settings_name = "front-loadbalancer-backend-settings"
#   }
# }


