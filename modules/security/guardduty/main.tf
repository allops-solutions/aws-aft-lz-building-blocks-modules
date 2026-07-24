# ==============================================================================
# Amazon GuardDuty — Organization-wide Configuration
#
# This module registers the delegated administrator, configures organization-
# level protection plans, enables malware protection service access, and
# explicitly enrolls all AFT-managed accounts as GuardDuty members.
# ==============================================================================

# ------------------------------------------------------------------------------
# GuardDuty detector in the delegated administrator (security/audit) account.
# Must exist before delegation. On subsequent applies this is a no-op since
# the detector already exists.
# ------------------------------------------------------------------------------
resource "aws_guardduty_detector" "this" {
  enable = true
}

# ------------------------------------------------------------------------------
# Delegate GuardDuty admin to the security/audit account (from management account)
# ------------------------------------------------------------------------------
resource "aws_guardduty_organization_admin_account" "this" {
  provider = aws.org-management

  admin_account_id = var.delegated_admin_account_id

  depends_on = [aws_guardduty_detector.this]
}

# ------------------------------------------------------------------------------
# GuardDuty detector in the organization management account. Must be enabled
# before the management account can be enrolled as a member.
# ------------------------------------------------------------------------------
resource "aws_guardduty_detector" "management" {
  provider = aws.org-management
  enable   = true

  depends_on = [aws_guardduty_organization_admin_account.this]
}

# ------------------------------------------------------------------------------
# Pause after enabling GuardDuty on the management account. Enabling the
# detector in the org master is not immediately visible to the delegated
# administrator's member-enrollment API. Without a sufficient delay, enrolling
# the management account as a member fails with:
#   "Operation failed because your organization master must first enable
#    GuardDuty to be added as a member"
#
# time_sleep only pauses on create (no triggers), so this cost is paid once on
# initial provisioning, not on every apply. 60s comfortably covers propagation.
# ------------------------------------------------------------------------------
resource "time_sleep" "after_management_detector" {
  create_duration = "60s"

  depends_on = [aws_guardduty_detector.management]
}

# ------------------------------------------------------------------------------
# Enable trusted access for Malware Protection. Without this, the delegated
# administrator cannot create the Malware Protection service-linked role in
# member accounts, resulting in a console warning:
# "Your organization's management account has not allowed the delegated
# administrator to attach relevant permissions..."
#
# Equivalent to: aws organizations enable-aws-service-access \
#   --service-principal malware-protection.guardduty.amazonaws.com
# ------------------------------------------------------------------------------
resource "terraform_data" "malware_protection_service_access" {
  triggers_replace = [var.delegated_admin_account_id]

  provisioner "local-exec" {
    command = <<-EOT
      aws organizations enable-aws-service-access \
        --service-principal malware-protection.guardduty.amazonaws.com \
        --profile "ct-management"
    EOT
  }

  depends_on = [aws_guardduty_organization_admin_account.this]
}

# ------------------------------------------------------------------------------
# Organization configuration: disable auto-enable so that only explicitly
# enrolled member accounts receive GuardDuty protection. This gives full
# control over which accounts are managed.
# ------------------------------------------------------------------------------
resource "aws_guardduty_organization_configuration" "this" {
  auto_enable_organization_members = "NONE"
  detector_id                      = aws_guardduty_detector.this.id

  depends_on = [aws_guardduty_organization_admin_account.this]
}

# ------------------------------------------------------------------------------
# Organization-level feature configuration. Sets the protection plan status
# for member accounts managed by this delegated administrator.
# Includes the deprecated EKS_RUNTIME_MONITORING explicitly set to NONE.
# ------------------------------------------------------------------------------
resource "aws_guardduty_organization_configuration_feature" "this" {
  for_each = local.organization_features

  detector_id = aws_guardduty_detector.this.id
  name        = each.key
  auto_enable = each.value

  dynamic "additional_configuration" {
    for_each = (
      each.key == "RUNTIME_MONITORING" ? local.runtime_monitoring_additional :
      each.key == "EKS_RUNTIME_MONITORING" ? local.eks_runtime_monitoring_additional :
      []
    )
    content {
      name        = additional_configuration.value.name
      auto_enable = additional_configuration.value.auto_enable
    }
  }

  depends_on = [aws_guardduty_organization_configuration.this]
}

# ------------------------------------------------------------------------------
# Member account enrollment. Creates a GuardDuty member association for each
# discovered account. Once a member is created under a delegated admin with
# auto_enable = NONE, the org-level feature settings still apply to members
# created through the organization integration.
# ------------------------------------------------------------------------------
resource "aws_guardduty_member" "this" {
  for_each = local.member_account_ids

  account_id  = each.value
  detector_id = aws_guardduty_detector.this.id
  email       = "placeholder@example.com"

  lifecycle {
    ignore_changes = [email, invite]
  }

  depends_on = [
    aws_guardduty_organization_configuration.this,
    aws_guardduty_organization_configuration_feature.this,
    terraform_data.malware_protection_service_access,
    time_sleep.after_management_detector,
  ]
}
