output "vnet_id" {
  description = "Resource ID of the VNet"
  value       = module.vnet.vnet_id
}

output "vnet_name" {
  description = "Name of the VNet"
  value       = module.vnet.vnet_name
}

output "subnet_ids" {
  description = "Subnet name to resource ID map"
  value       = module.vnet.subnet_ids
}

output "resource_group" {
  description = "Resource group name"
  value       = module.vnet.resource_group_name
}
