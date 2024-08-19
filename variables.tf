variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "demo-stage"
}

variable "location" {
  description = "The Azure region to deploy the resources"
  type        = string
  default     = "Central US"
}

variable "vnet_name" {
  description = "Name of Virtual Network"
  type        = string
  default     = "Xipper-Vnet"
}
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "public_nsg_name" {
  description = "The name of the virtual network"
  type        = string
  default     = "xipper-public-nsg"
}

variable "private_nsg_name" {
  description = "The name of the virtual network"
  type        = string
  default     = "xipper-private-nsg"
}

variable "public_vm_name" {
  description = "The name of the public virtual machine"
  type        = string
  default     = "xipper-public-vm"
}

variable "private_vm_name" {
  description = "The name of the private virtual machine"
  type        = string
  default     = "xipper-private-vm"
}







