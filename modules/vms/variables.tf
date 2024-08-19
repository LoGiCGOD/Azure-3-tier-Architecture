variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "The Azure region to deploy the resources"
  type        = string
}

variable "public_subnet_id" {
  description = "The ID of the public subnet"
  type        = string
}

variable "private_subnet_id" {
  description = "The ID of the private subnet"
  type        = string
}

variable "public_vm_name" {
  description = "The name of the public virtual machine"
  type        = string
}

variable "private_vm_name" {
  description = "The name of the private virtual machine"
  type        = string
}
