# ==============================================================================
# VPC Module
#
# Creates a VPC with public, private, and isolated subnets. Works in any account:
#   - Network account (centrally-managed): pass share_with_* to share subnets via RAM
#   - Member account (isolated): leave share_with_* empty, VPC stays local
#
# CIDR is allocated from an IPAM pool — no manual CIDR needed.
# ==============================================================================

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_vpc_ipam_pool" "this" {
  count      = var.ipam_pool_id != null ? 1 : 0
  ipam_pool_id = var.ipam_pool_id
}

locals {
  # Look up the IPAM pool to determine environment-based defaults
  ipam_pool_tags = var.ipam_pool_id != null ? data.aws_vpc_ipam_pool.this[0].tags : {}
  pool_environment = lookup(local.ipam_pool_tags, "environment", "")

  # Resolve nat_high_availability: if not explicitly set, default to true when
  # the IPAM pool is tagged as a production environment, false otherwise.
  nat_ha = coalesce(
    var.nat_high_availability,
    can(regex("prod", local.pool_environment)) && !can(regex("non-?prod", local.pool_environment))
  )

  az_ids         = slice(data.aws_availability_zones.available.zone_ids, 0, var.az_count)
  subnet_newbits = 4
  az_slots       = 4

  public_subnets = {
    for i, az in local.az_ids : az => cidrsubnet(aws_vpc.this.cidr_block, local.subnet_newbits, 0 * local.az_slots + i)
  }
  private_subnets = {
    for i, az in local.az_ids : az => cidrsubnet(aws_vpc.this.cidr_block, local.subnet_newbits, 1 * local.az_slots + i)
  }
  isolated_subnets = {
    for i, az in local.az_ids : az => cidrsubnet(aws_vpc.this.cidr_block, local.subnet_newbits, 2 * local.az_slots + i)
  }

  nat_azs = var.enable_egress ? (local.nat_ha ? local.az_ids : slice(local.az_ids, 0, 1)) : []
  nat_az_for = {
    for az in local.az_ids : az => (local.nat_ha ? az : local.az_ids[0])
  }

  all_route_table_ids = concat(
    [aws_route_table.public.id],
    [for rt in aws_route_table.private : rt.id],
    [aws_route_table.isolated.id],
  )

  # RAM sharing
  ram_principals         = concat(var.share_with_accounts, var.share_with_org_unit_arns)
  public_subnet_arns     = [for s in aws_subnet.public : s.arn]
  private_subnet_arns    = [for s in aws_subnet.private : s.arn]
  isolated_subnet_arns   = [for s in aws_subnet.isolated : s.arn]
  all_shared_subnet_arns = concat(local.public_subnet_arns, local.private_subnet_arns, local.isolated_subnet_arns)
}

# --- VPC ---

resource "aws_vpc" "this" {
  ipv4_ipam_pool_id   = var.ipam_pool_id
  ipv4_netmask_length = var.cidr_netmask_length

  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(var.tags, { Name = var.vpc_name })
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.vpc_name}-default-locked" })
}

# --- Internet Gateway ---

resource "aws_internet_gateway" "this" {
  count  = var.enable_egress ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.vpc_name}-igw" })
}

# --- Subnets ---

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone_id    = each.key
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${var.vpc_name}-public-${each.key}", Tier = "public" })
}

resource "aws_subnet" "private" {
  for_each = local.private_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone_id    = each.key
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${var.vpc_name}-private-${each.key}", Tier = "private" })
}

resource "aws_subnet" "isolated" {
  for_each = local.isolated_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone_id    = each.key
  map_public_ip_on_launch = false

  tags = merge(var.tags, { Name = "${var.vpc_name}-isolated-${each.key}", Tier = "isolated" })
}

# --- NAT Gateways ---

resource "aws_eip" "nat" {
  for_each = toset(local.nat_azs)
  domain   = "vpc"
  tags     = merge(var.tags, { Name = "${var.vpc_name}-nat-${each.key}" })
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_azs)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags       = merge(var.tags, { Name = "${var.vpc_name}-nat-${each.key}" })
  depends_on = [aws_internet_gateway.this]
}

# --- Route Tables ---

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.vpc_name}-public" })
}

resource "aws_route" "public_to_igw" {
  count = var.enable_egress ? 1 : 0

  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = toset(local.az_ids)
  vpc_id   = aws_vpc.this.id
  tags     = merge(var.tags, { Name = "${var.vpc_name}-private-${each.key}" })
}

resource "aws_route" "private_to_nat" {
  for_each = var.enable_egress ? toset(local.az_ids) : toset([])

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[local.nat_az_for[each.key]].id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route_table" "isolated" {
  vpc_id = aws_vpc.this.id
  tags   = merge(var.tags, { Name = "${var.vpc_name}-isolated" })
}

resource "aws_route_table_association" "isolated" {
  for_each       = aws_subnet.isolated
  subnet_id      = each.value.id
  route_table_id = aws_route_table.isolated.id
}

# --- Gateway VPC Endpoints (S3 + DynamoDB) ---

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.all_route_table_ids
  tags              = merge(var.tags, { Name = "${var.vpc_name}-s3" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = local.all_route_table_ids
  tags              = merge(var.tags, { Name = "${var.vpc_name}-dynamodb" })
}

# --- RAM Sharing (only when share_with_* is populated) ---

resource "aws_ram_resource_share" "subnets" {
  count = length(local.ram_principals) > 0 ? 1 : 0

  name                      = "${var.vpc_name}-subnets"
  allow_external_principals = false

  tags = merge(var.tags, { Name = "${var.vpc_name}-subnets" })
}

resource "aws_ram_resource_association" "subnets" {
  for_each = length(local.ram_principals) > 0 ? toset(local.all_shared_subnet_arns) : toset([])

  resource_arn       = each.value
  resource_share_arn = aws_ram_resource_share.subnets[0].arn
}

resource "aws_ram_principal_association" "principals" {
  for_each = length(local.ram_principals) > 0 ? toset(local.ram_principals) : toset([])

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.subnets[0].arn
}
