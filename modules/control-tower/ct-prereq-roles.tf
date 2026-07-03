# =============================================================================
# Control Tower Prerequisite IAM Roles
#
# These four service roles must exist in the management account BEFORE
# CreateLandingZone is called. When CT is set up via the console, the wizard
# creates them silently. When using the API / Terraform directly, they are our
# responsibility.
#
# References:
#   https://docs.aws.amazon.com/controltower/latest/userguide/lz-api-prereques.html
#   https://docs.aws.amazon.com/controltower/latest/userguide/access-control-managing-permissions.html
#   https://docs.aws.amazon.com/controltower/latest/userguide/roles-how.html
# =============================================================================

# -----------------------------------------------------------------------------
# AWSControlTowerAdmin
# Used by Control Tower itself to set up and manage the landing zone.
# Requires: AWSControlTowerServiceRolePolicy (managed) + a small inline policy.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "control_tower_admin" {
  name = "AWSControlTowerAdmin"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "controltower.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    ManagedBy = "terraform"
    Project   = "LandingZone"
  }
}

resource "aws_iam_role_policy_attachment" "control_tower_admin_service_role" {
  role       = aws_iam_role.control_tower_admin.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSControlTowerServiceRolePolicy"
}

resource "aws_iam_role_policy" "control_tower_admin_inline" {
  name = "AWSControlTowerAdminPolicy"
  role = aws_iam_role.control_tower_admin.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ec2:DescribeAvailabilityZones"
      Resource = "*"
    }]
  })
}

# -----------------------------------------------------------------------------
# AWSControlTowerCloudTrailRole
# Assumed by CloudTrail to create and publish CT audit logs to CloudWatch Logs.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "control_tower_cloudtrail" {
  name = "AWSControlTowerCloudTrailRole"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    ManagedBy = "terraform"
    Project   = "LandingZone"
  }
}

resource "aws_iam_role_policy_attachment" "control_tower_cloudtrail_managed" {
  role       = aws_iam_role.control_tower_cloudtrail.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSControlTowerCloudTrailRolePolicy"
}

# -----------------------------------------------------------------------------
# AWSControlTowerStackSetRole
# Assumed by CloudFormation to deploy stack sets into accounts created by CT.
# Inline policy allows it to assume AWSControlTowerExecution in any account.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "control_tower_stackset" {
  name = "AWSControlTowerStackSetRole"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudformation.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    ManagedBy = "terraform"
    Project   = "LandingZone"
  }
}

resource "aws_iam_role_policy" "control_tower_stackset_inline" {
  name = "AWSControlTowerStackSetRolePolicy"
  role = aws_iam_role.control_tower_stackset.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = "arn:aws:iam::*:role/AWSControlTowerExecution"
    }]
  })
}

# -----------------------------------------------------------------------------
# AWSControlTowerConfigAggregatorRoleForOrganizations
# Assumed by AWS Config to create an org-level aggregator in the management
# account. Required for landing zone versions < 4.0; in 4.0+ CT migrates to
# a service-linked aggregator, but the role must still exist at creation time.
# -----------------------------------------------------------------------------
resource "aws_iam_role" "control_tower_config_aggregator" {
  name = "AWSControlTowerConfigAggregatorRoleForOrganizations"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    ManagedBy = "terraform"
    Project   = "LandingZone"
  }
}

resource "aws_iam_role_policy_attachment" "control_tower_config_aggregator_managed" {
  role       = aws_iam_role.control_tower_config_aggregator.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRoleForOrganizations"
}

# -----------------------------------------------------------------------------
# IAM propagation delay
#
# IAM is eventually consistent. New roles and policy attachments can take a few
# seconds to propagate globally before Control Tower can assume them.
# This sleep sits between the role/policy resources and the landing zone so
# CreateLandingZone never races against IAM propagation.
# -----------------------------------------------------------------------------
resource "time_sleep" "ct_iam_propagation" {
  create_duration = "10s"

  depends_on = [
    aws_iam_role_policy_attachment.control_tower_admin_service_role,
    aws_iam_role_policy.control_tower_admin_inline,
    aws_iam_role_policy_attachment.control_tower_cloudtrail_managed,
    aws_iam_role_policy.control_tower_stackset_inline,
    aws_iam_role_policy_attachment.control_tower_config_aggregator_managed,
  ]
}
