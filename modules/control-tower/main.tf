# =============================================================================
# AWS Control Tower Landing Zone Module
# Creates the organization, IAM roles, landing zone, and permission set.
# =============================================================================

# --- Organization ---
# The organization is managed by Control Tower, not by this module.
# We only reference it here for dependency ordering.
data "aws_organizations_organization" "this" {}

# =============================================================================
# Centralized Root Access Management
# =============================================================================

resource "aws_iam_organizations_features" "root_access" {
  count = var.enable_centralized_root_access ? 1 : 0

  enabled_features = [
    "RootCredentialsManagement",
    "RootSessions",
  ]

  # IAM trusted access for Organizations is only available once the landing
  # zone has been created and CT has enabled the required service integrations.
  depends_on = [aws_controltower_landing_zone.this]
}

# =============================================================================
# RAM - Enable sharing with AWS Organizations
# =============================================================================

resource "aws_ram_sharing_with_organization" "this" {}

# --- Landing Zone Manifest ---
# Each conditional section is built as a JSON string then decoded back to an
# object. This sidesteps Terraform's strict conditional type matching, which
# requires both ternary branches to have identical object shapes.
locals {
  security_roles_section = jsondecode(var.enable_config ? jsonencode({
    securityRoles = {
      enabled   = true
      accountId = var.audit_account_id
    }
    }) : jsonencode({
    securityRoles = {
      enabled = false
    }
  }))

  centralized_logging_kms = var.kms_key_arn != "" ? { kmsKeyArn = var.kms_key_arn } : {}

  centralized_logging_section = jsondecode(var.enable_centralized_logging ? jsonencode({
    centralizedLogging = {
      enabled   = true
      accountId = var.log_archive_account_id
      configurations = merge(
        {
          loggingBucket = {
            retentionDays = var.logging_bucket_retention_days
          }
          accessLoggingBucket = {
            retentionDays = var.access_logging_bucket_retention_days
          }
        },
        local.centralized_logging_kms,
      )
    }
    }) : jsonencode({
    centralizedLogging = {
      enabled = false
    }
  }))

  backup_section = jsondecode(var.enable_backup ? jsonencode({
    backup = {
      enabled = true
      configurations = {
        centralBackup = {
          accountId = var.backup_central_account_id
        }
        backupAdmin = {
          accountId = var.backup_admin_account_id
        }
        kmsKeyArn = var.backup_kms_key_arn
      }
    }
    }) : jsonencode({
    backup = {
      enabled = false
    }
  }))

  config_kms = var.config_kms_key_arn != "" ? { kmsKeyArn = var.config_kms_key_arn } : {}

  config_section = jsondecode(var.enable_config ? jsonencode({
    config = {
      enabled   = true
      accountId = var.config_account_id
      configurations = merge(
        {
          loggingBucket = {
            retentionDays = var.config_logging_bucket_retention_days
          }
          accessLoggingBucket = {
            retentionDays = var.config_access_logging_bucket_retention_days
          }
        },
        local.config_kms,
      )
    }
    }) : jsonencode({
    config = {
      enabled = false
    }
  }))

  manifest = merge(
    {
      governedRegions = var.governed_regions
      accessManagement = {
        enabled = var.enable_access_management
      }
    },
    local.security_roles_section,
    local.centralized_logging_section,
    local.backup_section,
    local.config_section,
  )
}

# --- Landing Zone ---
resource "aws_controltower_landing_zone" "this" {
  manifest_json     = jsonencode(local.manifest)
  version           = var.landing_zone_version
  remediation_types = ["INHERITANCE_DRIFT"] # https://docs.aws.amazon.com/controltower/latest/userguide/account-auto-enrollment.html

  # Prerequisite roles must exist before CreateLandingZone is called.
  # CT needs them to perform its own setup; they don't exist until we create them.
  depends_on = [
    aws_iam_role_policy_attachment.control_tower_admin_service_role,
    aws_iam_role_policy.control_tower_admin_inline,
    aws_iam_role_policy_attachment.control_tower_cloudtrail_managed,
    aws_iam_role_policy.control_tower_stackset_inline,
    aws_iam_role_policy_attachment.control_tower_config_aggregator_managed,
    aws_ram_sharing_with_organization.this,
  ]
}

# --- Identity Center Permission Set (only when CT manages Identity Center) ---
data "aws_ssoadmin_instances" "this" {
  count      = var.enable_access_management ? 1 : 0
  depends_on = [aws_controltower_landing_zone.this]
}

locals {
  identity_center_instance_arn = var.enable_access_management ? tolist(data.aws_ssoadmin_instances.this[0].arns)[0] : null
}

resource "aws_ssoadmin_permission_set" "control_tower_administrator" {
  count = var.enable_access_management ? 1 : 0

  name             = "Control-Tower-Administrator"
  description      = "Full administrator access for Control Tower management"
  instance_arn     = local.identity_center_instance_arn
  session_duration = "PT4H"

  depends_on = [aws_controltower_landing_zone.this]
}

resource "aws_ssoadmin_managed_policy_attachment" "admin_access" {
  count = var.enable_access_management ? 1 : 0

  instance_arn       = local.identity_center_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.control_tower_administrator[0].arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
