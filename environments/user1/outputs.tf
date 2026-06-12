output "vm_public_ip" {
  description = "Public IP of the deployed Windows VM"
  value       = module.windows_vm.public_ip
}

output "vm_private_ip" {
  description = "Private IP of the deployed Windows VM"
  value       = module.windows_vm.private_ip
}

output "resource_group" {
  description = "Resource group name"
  value       = module.windows_vm.resource_group_name
}
