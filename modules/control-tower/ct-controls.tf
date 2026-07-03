# =============================================================================
# CT.MULTISERVICE.PV.1 — OU-Level Region Deny Control
#
# Applies the configurable region deny control to all CT-registered OUs:
#   - OUs passed in via var.region_deny_target_ou_arns (from the root module)
#   - Security OU (created by CT during LZ setup)
#   - Account Factory for Terraform OU (created by the AFT module)
#
# This replaces the landing-zone-level AWS-GR_REGION_DENY with a version we can
# keep up-to-date as AWS launches new global services.
#
# Built-in ExemptedActions cover known global/billing services that AWS has not
# yet added to the CT template. Additional exemptions (e.g., Bedrock cross-region
# inference) are passed in via var.region_deny_extra_exempted_actions.
# =============================================================================

data "aws_organizations_organizational_units" "root_level" {
  parent_id = data.aws_organizations_organization.this.roots[0].id
}

locals {
  # Built-in exemptions for global/billing services missing from the CT template.
  # These are always included regardless of what the caller passes.
  builtin_exempted_actions = [
    "bcm-dashboards:*",
    "bcm-data-exports:*",
    "bcm-pricing-calculator:*",
    "pricingplanmanager:*",
    "uxc:*",
  ]

  # Merge built-in + caller-provided extra exemptions
  all_exempted_actions = concat(
    local.builtin_exempted_actions,
    var.region_deny_extra_exempted_actions,
  )

  # CT-owned OUs looked up internally (not managed by the caller)
  ct_owned_ou_arns = {
    for ou in data.aws_organizations_organizational_units.root_level.children :
    ou.name => ou.arn
    if contains(["Security", "Account Factory for Terraform"], ou.name)
  }

  # All CT-registered OUs: caller-provided + CT-owned
  all_region_deny_targets = merge(var.region_deny_target_ou_arns, local.ct_owned_ou_arns)

  # Filter out excluded OUs from the target map
  region_deny_target_ous = {
    for name, arn in local.all_region_deny_targets :
    name => arn
    if !contains(var.region_deny_excluded_ou_names, name)
  }
}

resource "aws_controltower_control" "region_deny" {
  for_each = var.enable_region_deny_control ? local.region_deny_target_ous : {}

  control_identifier = "arn:aws:controlcatalog:::control/ka8e3pkqefnjsxuyc26ji580"
  target_identifier  = each.value

  parameters {
    key   = "AllowedRegions"
    value = jsonencode(var.governed_regions)
  }

  parameters {
    key   = "ExemptedActions"
    value = jsonencode(local.all_exempted_actions)
  }

  dynamic "parameters" {
    for_each = length(var.region_deny_exempted_principal_arns) > 0 ? [1] : []
    content {
      key   = "ExemptedPrincipalArns"
      value = jsonencode(var.region_deny_exempted_principal_arns)
    }
  }

  # Controls can only be enabled after the landing zone exists.
  depends_on = [aws_controltower_landing_zone.this]

  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
}
