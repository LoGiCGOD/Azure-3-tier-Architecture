variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "The Azure region to deploy the resources"
  type        = string
}

variable "public_nsg_name" {
  description = "The name of the virtual network"
  type        = string
}

variable "vnet_name" {
  description = "The name of the virtual network"
  type        = string
}
variable "subnet_ids" {
  description = "List of subnet IDs"
  type        = list(string)
}
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
}
variable "load_balancer_ip" {
  type        = string
  description = "The public IP address or address range of the load balancer."
}
