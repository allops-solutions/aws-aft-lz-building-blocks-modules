# ==============================================================================
# AWS Security Hub CSPM — Organization-wide Configuration
#
# This module enables Security Hub CSPM in the delegated administrator account,
# registers delegation, configures central organization mode with finding
# aggregation across all Regions, creates a configuration policy with selected
# security standards, and associates it with Control Tower-managed OUs.
# ==============================================================================

# ------------------------------------------------------------------------------
# Deployment gate — sequences this module's resources after the modules wired
# into var.deployment_dependencies (e.g. GuardDuty, Inspector). The module's
# entry resources depend on this gate. Because only resources (never data
# sources) reference it, the module's data sources are still read at plan time,
# so the for_each over organization OUs keeps working.
# ------------------------------------------------------------------------------
resource "terraform_data" "deployment_gate" {
  input = var.deployment_dependencies
}

# ------------------------------------------------------------------------------
# Enable Security Hub CSPM in the delegated administrator (security/audit)
# account. Uses consolidated control findings for cross-standard deduplication.
# ------------------------------------------------------------------------------
resource "aws_securityhub_account" "this" {
  control_finding_generator = "SECURITY_CONTROL"

  depends_on = [terraform_data.deployment_gate]
}

# ------------------------------------------------------------------------------
# Enable Security Hub CSPM in the organization management account. Must be
# enabled before the management account can be associated with a configuration
# policy.
# This should be potentially added in future if it is justified or needed as a
# variable option of the module. Control Tower does not enable Config in the Account
# ------------------------------------------------------------------------------
# resource "aws_securityhub_account" "management" {
#   provider = aws.org-management
#
#   control_finding_generator = "SECURITY_CONTROL"
# }

# ------------------------------------------------------------------------------
# Delegate Security Hub CSPM admin to the security/audit account (from the
# organization management account).
# ------------------------------------------------------------------------------
resource "aws_securityhub_organization_admin_account" "this" {
  provider = aws.org-management

  admin_account_id = var.delegated_admin_account_id

  depends_on = [terraform_data.deployment_gate]
}

# ------------------------------------------------------------------------------
# Finding aggregator — aggregate findings from the specified Regions into the
# home Region. Only the primary and secondary Regions (plus any additional
# Regions) are linked. This is required before enabling CENTRAL configuration.
# ------------------------------------------------------------------------------
resource "aws_securityhub_finding_aggregator" "this" {
  linking_mode      = "SPECIFIED_REGIONS"
  specified_regions = local.linked_regions

  depends_on = [aws_securityhub_organization_admin_account.this]
}

# ------------------------------------------------------------------------------
# Pause to let the organization data finish syncing before enabling CENTRAL
# configuration. Registering the delegated administrator kicks off an
# asynchronous organization sync. Enabling central configuration before that
# sync completes fails with:
#   "Central configuration couldn't be enabled because data from organization
#    <org-id> is still syncing. Retry later." (ResourceNotFoundException, 404)
#
# The clock starts at delegated-admin registration (the sync trigger), so the
# aggregator creation overlaps this window. time_sleep only pauses on create
# (no triggers), so this cost is paid once on initial provisioning.
# ------------------------------------------------------------------------------
resource "time_sleep" "after_org_admin_sync" {
  create_duration = "90s"

  depends_on = [
    aws_securityhub_organization_admin_account.this,
    aws_securityhub_finding_aggregator.this,
  ]
}

# ------------------------------------------------------------------------------
# Organization configuration — CENTRAL mode. Disables legacy auto-enable so
# that all account configuration is managed exclusively through configuration
# policies.
# ------------------------------------------------------------------------------
resource "aws_securityhub_organization_configuration" "this" {
  auto_enable           = false
  auto_enable_standards = "NONE"

  organization_configuration {
    configuration_type = "CENTRAL"
  }

  depends_on = [
    aws_securityhub_finding_aggregator.this,
    time_sleep.after_org_admin_sync,
  ]
}

# ------------------------------------------------------------------------------
# Configuration policy — defines which standards and controls are enabled for
# associated accounts. The policy enables the service, activates the selected
# standards, and optionally disables specific controls.
#
# The replace_triggered_by lifecycle ensures that if the policy needs to be
# recreated, the associations are destroyed first (avoiding the 409 conflict).
# ------------------------------------------------------------------------------
resource "aws_securityhub_configuration_policy" "this" {
  name        = "securityhub-cspm-enable"
  description = "Organization-wide Security Hub CSPM configuration policy with selected security standards."

  configuration_policy {
    service_enabled       = true
    enabled_standard_arns = local.enabled_standard_arns

    security_controls_configuration {
      disabled_control_identifiers = var.disabled_control_identifiers
    }
  }

  depends_on = [aws_securityhub_organization_configuration.this]
}

# ------------------------------------------------------------------------------
# Policy association — attach the configuration policy to each CT-managed OU.
# Accounts within the targeted OUs automatically inherit the policy.
#
# Uses create_before_destroy = false (default) to ensure disassociation
# completes before any policy replacement. The provisioner adds a brief delay
# after disassociation to allow the API to propagate.
# ------------------------------------------------------------------------------
resource "aws_securityhub_configuration_policy_association" "this" {
  for_each = local.association_targets

  target_id = each.value
  policy_id = aws_securityhub_configuration_policy.this.id

  provisioner "local-exec" {
    when    = destroy
    command = "sleep 5"
  }
}
