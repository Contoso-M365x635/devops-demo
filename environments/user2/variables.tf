variable "resource_group_name" {
  description = "Resource group for the VNet"
  type        = string
  default     = "rg-devops-demo-net"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "australiaeast"
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
  default     = "demo-vnet"
}

variable "address_space" {
  description = "Address space CIDR blocks"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnets" {
  description = "Map of subnet name to CIDR prefix"
  type        = map(string)
  default = {
    "subnet-web" = "10.0.1.0/24"
    "subnet-app" = "10.0.2.0/24"
    "subnet-db"  = "10.0.3.0/24"
  }
}
