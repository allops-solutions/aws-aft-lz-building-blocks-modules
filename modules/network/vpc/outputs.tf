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

output "default_security_group_id" {
  description = "The ID of the security group created by default on VPC creation."
  value       = aws_vpc.this.default_security_group_id
}

output "default_network_acl_id" {
  description = "The ID of the default network ACL."
  value       = aws_vpc.this.default_network_acl_id
}

output "default_route_table_id" {
  description = "The ID of the default route table."
  value       = aws_vpc.this.default_route_table_id
}

output "vpc_instance_tenancy" {
  description = "Tenancy of instances launched into the VPC."
  value       = aws_vpc.this.instance_tenancy
}

output "vpc_enable_dns_support" {
  description = "Whether the VPC has DNS support."
  value       = aws_vpc.this.enable_dns_support
}

output "vpc_enable_dns_hostnames" {
  description = "Whether the VPC has DNS hostname support."
  value       = aws_vpc.this.enable_dns_hostnames
}

output "vpc_main_route_table_id" {
  description = "The ID of the main route table associated with this VPC."
  value       = aws_vpc.this.main_route_table_id
}

output "vpc_ipv6_association_id" {
  description = "IPv6 CIDR association ID. Always null because this module does not provision IPv6 CIDR blocks."
  value       = null
}

output "vpc_ipv6_cidr_block" {
  description = "IPv6 CIDR block. Always null because this module does not provision IPv6 CIDR blocks."
  value       = null
}

output "vpc_secondary_cidr_blocks" {
  description = "Secondary IPv4 CIDR blocks. Always empty because this module provisions only the primary IPAM-allocated CIDR."
  value       = []
}

output "vpc_owner_id" {
  description = "The ID of the AWS account that owns the VPC."
  value       = aws_vpc.this.owner_id
}

output "name" {
  description = "The name of the VPC specified as argument to this module."
  value       = var.vpc_name
}

output "azs" {
  description = "A list of Availability Zone IDs used by this VPC."
  value       = local.az_ids
}

output "igw_id" {
  description = "The ID of the Internet Gateway."
  value       = var.enable_egress ? aws_internet_gateway.this[0].id : null
}

output "igw_arn" {
  description = "The ARN of the Internet Gateway."
  value       = var.enable_egress ? aws_internet_gateway.this[0].arn : null
}

output "egress_only_internet_gateway_id" {
  description = "ID of the egress-only Internet Gateway. Always null because this module provisions IPv4 egress only."
  value       = null
}

output "public_subnet_ids_by_az" {
  description = "Map of Availability Zone ID to public subnet ID."
  value       = { for k, v in aws_subnet.public : k => v.id }
}

output "public_subnet_objects" {
  description = "A list of all public subnets, containing the full objects."
  value       = [for az in local.az_ids : aws_subnet.public[az]]
}

output "public_subnets" {
  description = "List of IDs of public subnets."
  value       = [for az in local.az_ids : aws_subnet.public[az].id]
}

output "public_subnet_arns" {
  description = "List of ARNs of public subnets."
  value       = local.public_subnet_arns
}

output "public_subnets_cidr_blocks" {
  description = "List of CIDR blocks of public subnets."
  value       = [for az in local.az_ids : aws_subnet.public[az].cidr_block]
}

output "public_subnets_ipv6_cidr_blocks" {
  description = "IPv6 CIDR blocks of public subnets. Always empty because this module does not provision IPv6 CIDR blocks."
  value       = []
}

output "public_network_acl_id" {
  description = "ID of the dedicated public network ACL. Always null because this module uses the default network ACL."
  value       = null
}

output "public_network_acl_arn" {
  description = "ARN of the dedicated public network ACL. Always null because this module uses the default network ACL."
  value       = null
}

output "public_route_table_ids" {
  description = "List of IDs of public route tables."
  value       = [aws_route_table.public.id]
}

output "public_internet_gateway_route_id" {
  description = "ID of the Internet Gateway route."
  value       = var.enable_egress ? aws_route.public_to_igw[0].id : null
}

output "public_route_table_association_ids" {
  description = "List of IDs of public route table associations."
  value       = [for az in local.az_ids : aws_route_table_association.public[az].id]
}

output "private_subnet_ids_by_az" {
  description = "Map of Availability Zone ID to private subnet ID."
  value       = { for k, v in aws_subnet.private : k => v.id }
}

output "private_subnet_objects" {
  description = "A list of all private subnets, containing the full objects."
  value       = [for az in local.az_ids : aws_subnet.private[az]]
}

output "private_subnets" {
  description = "List of IDs of private subnets."
  value       = [for az in local.az_ids : aws_subnet.private[az].id]
}

output "private_subnet_arns" {
  description = "List of ARNs of private subnets."
  value       = local.private_subnet_arns
}

output "private_subnets_cidr_blocks" {
  description = "List of CIDR blocks of private subnets."
  value       = [for az in local.az_ids : aws_subnet.private[az].cidr_block]
}

output "private_subnets_ipv6_cidr_blocks" {
  description = "IPv6 CIDR blocks of private subnets. Always empty because this module does not provision IPv6 CIDR blocks."
  value       = []
}

output "private_network_acl_id" {
  description = "ID of the dedicated private network ACL. Always null because this module uses the default network ACL."
  value       = null
}

output "private_network_acl_arn" {
  description = "ARN of the dedicated private network ACL. Always null because this module uses the default network ACL."
  value       = null
}

output "private_route_table_ids_by_az" {
  description = "Map of Availability Zone ID to private route table ID."
  value       = { for k, v in aws_route_table.private : k => v.id }
}

output "private_route_table_ids" {
  description = "List of IDs of private route tables."
  value       = [for az in local.az_ids : aws_route_table.private[az].id]
}

output "private_nat_gateway_route_ids" {
  description = "List of IDs of private NAT Gateway routes."
  value       = var.enable_egress ? [for az in local.az_ids : aws_route.private_to_nat[az].id] : []
}

output "private_route_table_association_ids" {
  description = "List of IDs of private route table associations."
  value       = [for az in local.az_ids : aws_route_table_association.private[az].id]
}

output "intra_subnet_ids_by_az" {
  description = "Map of Availability Zone ID to intra subnet ID."
  value       = { for k, v in aws_subnet.isolated : k => v.id }
}

output "intra_subnet_objects" {
  description = "A list of all intra subnets, containing the full objects."
  value       = [for az in local.az_ids : aws_subnet.isolated[az]]
}

output "intra_subnets" {
  description = "List of IDs of intra subnets."
  value       = [for az in local.az_ids : aws_subnet.isolated[az].id]
}

output "intra_subnet_arns" {
  description = "List of ARNs of intra subnets."
  value       = local.isolated_subnet_arns
}

output "intra_subnets_cidr_blocks" {
  description = "List of CIDR blocks of intra subnets."
  value       = [for az in local.az_ids : aws_subnet.isolated[az].cidr_block]
}

output "intra_subnets_ipv6_cidr_blocks" {
  description = "IPv6 CIDR blocks of intra subnets. Always empty because this module does not provision IPv6 CIDR blocks."
  value       = []
}

output "intra_network_acl_id" {
  description = "ID of the dedicated intra network ACL. Always null because this module uses the default network ACL."
  value       = null
}

output "intra_network_acl_arn" {
  description = "ARN of the dedicated intra network ACL. Always null because this module uses the default network ACL."
  value       = null
}

output "intra_route_table_ids" {
  description = "List of IDs of intra route tables."
  value       = [aws_route_table.isolated.id]
}

output "intra_route_table_association_ids" {
  description = "List of IDs of intra route table associations."
  value       = [for az in local.az_ids : aws_route_table_association.isolated[az].id]
}

output "nat_ids_by_az" {
  description = "Map of Availability Zone ID to NAT Gateway Elastic IP allocation ID."
  value       = { for k, v in aws_eip.nat : k => v.id }
}

output "nat_ids" {
  description = "List of Elastic IP allocation IDs created for NAT Gateways."
  value       = [for az in local.nat_azs : aws_eip.nat[az].id]
}

output "nat_public_ips_by_az" {
  description = "Map of Availability Zone ID to NAT Gateway public IP."
  value       = { for k, v in aws_eip.nat : k => v.public_ip }
}

output "nat_public_ips" {
  description = "List of public Elastic IPs created for NAT Gateways."
  value       = [for az in local.nat_azs : aws_eip.nat[az].public_ip]
}

output "natgw_ids_by_az" {
  description = "Map of Availability Zone ID to NAT Gateway ID."
  value       = { for k, v in aws_nat_gateway.this : k => v.id }
}

output "natgw_ids" {
  description = "List of NAT Gateway IDs."
  value       = [for az in local.nat_azs : aws_nat_gateway.this[az].id]
}

output "natgw_interface_ids" {
  description = "List of Network Interface IDs assigned to NAT Gateways."
  value       = [for az in local.nat_azs : aws_nat_gateway.this[az].network_interface_id]
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
