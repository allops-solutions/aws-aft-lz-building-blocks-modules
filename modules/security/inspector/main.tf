# ------------------------------------------------------------------------------
# Regions where Amazon Inspector is enabled (deduplicated, order-independent),
# and the enablement object for the organization policy. Only scan types that
# are turned on are included, so the policy (and its console view) lists exactly
# what is enabled — disabled scan types are simply left unmanaged rather than
# explicitly disabled everywhere.
# ------------------------------------------------------------------------------
locals {
  regions = toset(concat(
    [var.primary_region],
    var.enable_secondary_region ? [var.secondary_region] : [],
    var.additional_regions,
  ))
  region_list = tolist(local.regions)

  # Allow child policies (OUs/accounts below the attachment point) to use any
  # value-setting operator, for both enabled and disabled Regions. This is the
  # AWS default and the console-recommended setting; set explicitly here.
  child_ops = { "@@operators_allowed_for_child_policies" = ["@@all"] }

  enable_here  = merge(local.child_ops, { "@@assign" = local.region_list })
  disable_none = merge(local.child_ops, { "@@assign" = [] })

  enablement = merge(
    var.ec2_scanning_enabled ? {
      ec2_scanning = { enable_in_regions = local.enable_here, disable_in_regions = local.disable_none }
    } : {},
    var.ecr_scanning_enabled ? {
      ecr_scanning = { enable_in_regions = local.enable_here, disable_in_regions = local.disable_none }
    } : {},
    (var.lambda_standard_scanning_enabled || var.lambda_code_scanning_enabled) ? {
      lambda_standard_scanning = merge(
        {
          enable_in_regions  = merge(local.child_ops, { "@@assign" = var.lambda_standard_scanning_enabled ? local.region_list : [] })
          disable_in_regions = local.disable_none
        },
        var.lambda_code_scanning_enabled ? {
          lambda_code_scanning = { enable_in_regions = local.enable_here, disable_in_regions = local.disable_none }
        } : {},
      )
    } : {},
    var.code_repository_scanning_enabled ? {
      code_repository_scanning = { enable_in_regions = local.enable_here, disable_in_regions = local.disable_none }
    } : {},
  )

  any_enabled = length(local.enablement) > 0
}
# Activate Amazon Inspector inside the delegated administrator account itself,
# once per managed Region. Registering the delegated administrator above only
# delegates management; it does not enable the service for the account, so its
# console shows "Activate Inspector" with no dashboard until this runs. AWS
# requires at least one scan type to activate the service; ECR is used since a
# security-tooling account hosts no scannable resources, so activation is free.
# ------------------------------------------------------------------------------
resource "aws_inspector2_enabler" "delegated_admin" {
  for_each = local.regions

  region = each.value

  account_ids    = [var.delegated_admin_account_id]
  resource_types = ["ECR"]

  depends_on = [aws_inspector2_delegated_admin_account.this]
}

# ------------------------------------------------------------------------------
# Delegate Amazon Inspector admin to this account (from the management account)
# ------------------------------------------------------------------------------
resource "aws_inspector2_delegated_admin_account" "this" {
  provider = aws.org-management

  account_id = var.delegated_admin_account_id
}
# ------------------------------------------------------------------------------
# Amazon Inspector organization policy. Enables the selected scan types in the
# managed Regions and is attached to the resolved, non-excluded organizational
# units. AWS Organizations auto-enables Amazon Inspector for every existing and
# future account under those OUs, so new member accounts activate automatically.
# Created only when at least one scan type is enabled.
# ------------------------------------------------------------------------------
resource "aws_organizations_policy" "enable" {
  count    = local.any_enabled ? 1 : 0
  provider = aws.org-management

  name        = "inspector-enable"
  description = "Amazon Inspector scan enablement for managed organizational units."
  type        = "INSPECTOR_POLICY"

  content = jsonencode({
    inspector = {
      enablement = local.enablement
    }
  })

  tags = var.tags

  depends_on = [aws_inspector2_delegated_admin_account.this]
}

resource "aws_organizations_policy_attachment" "enable" {
  for_each = local.any_enabled ? local.association_targets : toset([])
  provider = aws.org-management

  policy_id = aws_organizations_policy.enable[0].id
  target_id = each.value
}

# ------------------------------------------------------------------------------
# Explicit account-level override: disables every scan type, in every managed
# Region, for accounts listed in excluded_account_ids. Attached directly to
# the account so it takes precedence over the inherited OU-level enablement
# policy.
# ------------------------------------------------------------------------------
resource "aws_organizations_policy" "disable_excluded_accounts" {
  count    = local.has_excluded_accounts ? 1 : 0
  provider = aws.org-management

  name        = "inspector-disable-excluded-accounts"
  description = "Disables Amazon Inspector scanning for accounts explicitly excluded from organization-wide enablement."
  type        = "INSPECTOR_POLICY"

  content = jsonencode({
    inspector = {
      enablement = {
        ec2_scanning = {
          enable_in_regions  = { "@@assign" = [] }
          disable_in_regions = { "@@assign" = tolist(local.regions) }
        }
        ecr_scanning = {
          enable_in_regions  = { "@@assign" = [] }
          disable_in_regions = { "@@assign" = tolist(local.regions) }
        }
        lambda_standard_scanning = {
          enable_in_regions  = { "@@assign" = [] }
          disable_in_regions = { "@@assign" = tolist(local.regions) }
          lambda_code_scanning = {
            enable_in_regions  = { "@@assign" = [] }
            disable_in_regions = { "@@assign" = tolist(local.regions) }
          }
        }
        code_repository_scanning = {
          enable_in_regions  = { "@@assign" = [] }
          disable_in_regions = { "@@assign" = tolist(local.regions) }
        }
      }
    }
  })

  tags = var.tags

  depends_on = [aws_inspector2_delegated_admin_account.this]
}

resource "aws_organizations_policy_attachment" "disable_excluded_accounts" {
  for_each = local.has_excluded_accounts ? toset(var.excluded_account_ids) : toset([])
  provider = aws.org-management

  policy_id = aws_organizations_policy.disable_excluded_accounts[0].id
  target_id = each.value
}

# ------------------------------------------------------------------------------
# ECR continuous re-scanning window
#
# Configures how long Amazon Inspector keeps re-scanning ECR images for new
# vulnerabilities. No native Terraform resource exists for this setting, so it
# is applied via the CLI on every run to ensure convergence. The re-scan window
# (var.ecr_rescan_window) controls both the push-date and last-in-use timers;
# images that are no longer in use stop being re-scanned after the window
# expires.
# ------------------------------------------------------------------------------
resource "terraform_data" "ecr_rescan_duration" {
  count = local.any_enabled ? 1 : 0

  triggers_replace = [timestamp()]

  provisioner "local-exec" {
    command = <<-EOT
      aws inspector2 update-configuration \
        --region "${var.primary_region}" \
        --profile "aft-target" \
        --ecr-configuration 'rescanDuration=${var.ecr_rescan_window},pullDateRescanDuration=${var.ecr_rescan_window},pullDateRescanMode=LAST_IN_USE_AT'
    EOT
  }

  depends_on = [
    aws_inspector2_delegated_admin_account.this,
    aws_organizations_policy.enable,
    aws_inspector2_enabler.delegated_admin,
    aws_organizations_policy_attachment.enable,
    aws_organizations_policy.disable_excluded_accounts,
    aws_organizations_policy_attachment.disable_excluded_accounts,
  ]
}
