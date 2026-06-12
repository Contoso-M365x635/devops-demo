variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "australiaeast"
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  default     = "demo-win-vm"
}

variable "vm_size" {
  description = "Azure VM size"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "VM administrator username"
  type        = string
  default     = "demoadmin"
}

variable "admin_password" {
  description = "VM administrator password"
  type        = string
  sensitive   = true
}
