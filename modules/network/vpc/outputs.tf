# ==============================================================================
# VPC Module — Outputs
# ==============================================================================

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_arn" {
  description = "VPC ARN."
  value       = aws_vpc.this.arn
}

output "vpc_cidr_block" {
  description = "CIDR block allocated from IPAM."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Map of AZ ID to public subnet ID."
  value       = { for k, v in aws_subnet.public : k => v.id }
}

output "public_subnet_arns" {
  description = "List of public subnet ARNs."
  value       = local.public_subnet_arns
}

output "private_subnet_ids" {
  description = "Map of AZ ID to private subnet ID."
  value       = { for k, v in aws_subnet.private : k => v.id }
}

output "private_subnet_id_list" {
  description = "Flat list of private subnet IDs (convenience for resources that expect a list, e.g. VPC endpoints)."
  value       = [for v in aws_subnet.private : v.id]
}

output "private_subnet_arns" {
  description = "List of private subnet ARNs."
  value       = local.private_subnet_arns
}

output "isolated_subnet_ids" {
  description = "Map of AZ ID to isolated subnet ID."
  value       = { for k, v in aws_subnet.isolated : k => v.id }
}

output "isolated_subnet_arns" {
  description = "List of isolated subnet ARNs."
  value       = local.isolated_subnet_arns
}

output "public_route_table_id" {
  description = "Public route table ID."
  value       = aws_route_table.public.id
}

output "private_route_table_ids" {
  description = "Map of AZ ID to private route table ID."
  value       = { for k, v in aws_route_table.private : k => v.id }
}

output "isolated_route_table_id" {
  description = "Isolated route table ID."
  value       = aws_route_table.isolated.id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID (null if egress disabled)."
  value       = var.enable_egress ? aws_internet_gateway.this[0].id : null
}

output "nat_gateway_ids" {
  description = "Map of AZ ID to NAT Gateway ID."
  value       = { for k, v in aws_nat_gateway.this : k => v.id }
}

output "nat_gateway_public_ips" {
  description = "Map of AZ ID to NAT Gateway public IP."
  value       = { for k, v in aws_eip.nat : k => v.public_ip }
}

output "availability_zone_ids" {
  description = "AZ IDs used by this VPC."
  value       = local.az_ids
}

output "ram_resource_share_arn" {
  description = "RAM resource share ARN (null if not shared)."
  value       = length(local.ram_principals) > 0 ? aws_ram_resource_share.subnets[0].arn : null
}

output "vpc_metadata" {
  description = "VPC summary for operational reference."
  value = {
    vpc_name              = var.vpc_name
    vpc_id                = aws_vpc.this.id
    cidr_block            = aws_vpc.this.cidr_block
    az_count              = var.az_count
    availability_zone_ids = local.az_ids
    has_internet_gateway  = var.enable_egress
    nat_configuration     = var.enable_egress ? (local.nat_ha ? "high-availability" : "single-az") : "none"
    is_shared             = length(local.ram_principals) > 0
  }
}
