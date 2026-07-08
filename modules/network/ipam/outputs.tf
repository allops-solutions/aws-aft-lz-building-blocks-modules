# ==============================================================================
# VPC IPAM Module — Outputs
# ==============================================================================

output "ipam_id" {
  description = "ID of the IPAM instance."
  value       = aws_vpc_ipam.this.id
}

output "ipam_arn" {
  description = "ARN of the IPAM instance."
  value       = aws_vpc_ipam.this.arn
}

output "ipam_private_default_scope_id" {
  description = "ID of the IPAM private default scope."
  value       = aws_vpc_ipam.this.private_default_scope_id
}

output "organization_pool_id" {
  description = "ID of the top-level organization IPAM pool."
  value       = aws_vpc_ipam_pool.organization.id
}

output "regional_pool_ids" {
  description = "Map of regional pool logical names to their IPAM pool IDs."
  value       = { for k, v in aws_vpc_ipam_pool.regional : k => v.id }
}

output "environment_pool_ids" {
  description = "Map of environment pool logical names to their IPAM pool IDs."
  value       = { for k, v in aws_vpc_ipam_pool_cidr.environment : k => v.ipam_pool_id }
}

output "environment_pool_arns" {
  description = "Map of environment pool logical names to their ARNs."
  value       = { for k, v in aws_vpc_ipam_pool.environment : k => v.arn }
}

output "ram_resource_share_arns" {
  description = "Map of environment pool name to its RAM resource share ARN (empty if sharing disabled)."
  value       = { for k, v in aws_ram_resource_share.ipam_pools : k => v.arn }
}
