variable "resource_group_name" {
  description = "Resource group for the Windows VM"
  type        = string
  default     = "rg-devops-demo-vm"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "australiaeast"
}

variable "vm_name" {
  description = "Name of the Windows VM"
  type        = string
  default     = "demo-win-vm"
}

variable "vm_size" {
  description = "VM SKU size"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Local admin username"
  type        = string
  default     = "demoadmin"
}

variable "admin_password" {
  description = "Local admin password (set via TF_VAR_admin_password or GitHub Secret)"
  type        = string
  sensitive   = true
}
