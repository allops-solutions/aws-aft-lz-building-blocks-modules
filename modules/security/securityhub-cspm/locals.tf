locals {
  # ----------------------------------------------------------------------------
  # CT-managed OU discovery — filter level-1 OUs that have at least one
  # Control Tower control enabled, excluding the Suspended OU.
  # ----------------------------------------------------------------------------
  ct_managed_ou_ids = {
    for name, controls in data.aws_controltower_controls.root_ous :
    name => one([
      for ou in data.aws_organizations_organizational_units.root.children :
      ou.id if ou.name == name
    ])
    if(length(controls.enabled_controls) > 0 && name != "Suspended" && name != "Security" && name != "Account Factory for Terraform")
    # Security OU should be potentially added in future if it is justified or needed as a
    # variable option of the module. Control Tower does not enable Config in the Account
  }

  # ----------------------------------------------------------------------------
  # Association targets — CT-managed OU IDs plus the delegated administrator
  # (audit) account itself.
  # Security Hub configuration policies can target OUs directly, so no need
  # to enumerate individual accounts. The audit account is not a member of a
  # CT-managed OU target, so it is added explicitly here to bring the account
  # this customization is deployed into under the configuration policy.
  # Control Tower enables AWS Config in the audit account, so it satisfies the
  # central-configuration prerequisite (unlike the management account).
  # ----------------------------------------------------------------------------
  management_account_id = data.aws_organizations_organization.org.master_account_id

  association_targets = setunion(
    toset(values(local.ct_managed_ou_ids)),
    toset([var.delegated_admin_account_id]),
    # toset([local.management_account_id]),
    # This should be potentially added in future if it is justified or needed as a
    # variable option of the module. Control Tower does not enable Config in the Account
  )

  # ----------------------------------------------------------------------------
  # Standard ARNs — built from the current region and individual toggles.
  # ----------------------------------------------------------------------------
  enabled_standard_arns = compact([
    var.foundational_security_enabled ? "arn:aws:securityhub:${var.region}::standards/aws-foundational-security-best-practices/v/1.0.0" : "",
    var.cis_benchmark_enabled ? "arn:aws:securityhub:${var.region}::standards/cis-aws-foundations-benchmark/v/5.0.0" : "",
    var.ai_security_enabled ? "arn:aws:securityhub:${var.region}::standards/ai-security-best-practices/v/1.0.0" : "",
    var.resource_tagging_enabled ? "arn:aws:securityhub:${var.region}::standards/aws-resource-tagging-standard/v/1.0.0" : "",
  ])

  # ----------------------------------------------------------------------------
  # Linked Regions — the set of Regions where Security Hub CSPM is enabled
  # beyond the home Region. The home Region (var.region) is always active and
  # must NOT appear in this list — the API rejects it.
  # ----------------------------------------------------------------------------
  linked_regions = distinct(compact(concat(
    [var.secondary_region],
    var.additional_regions,
  )))

  # ----------------------------------------------------------------------------
  # Notification severity filtering — severity labels are ordered from lowest to
  # highest. The EventBridge rule matches every label at or above the configured
  # minimum. INFORMATIONAL is intentionally never notified: passing Security Hub
  # control findings are INFORMATIONAL, so excluding it drops all "compliant"
  # noise while retaining GuardDuty/Inspector findings (which carry a real
  # severity and no Compliance status).
  # ----------------------------------------------------------------------------
  # The topic name and subscribed email are derived, not configured. The email
  # is this account's own root email (this is the Security Hub delegated admin,
  # i.e. the audit account), mirroring how Control Tower subscribes the audit
  # account to its aggregate topic. Recipients opt out by unsubscribing in SNS.
  notification_topic_name = "securityhub-finding-notifications"

  notification_email = one([
    for account in data.aws_organizations_organization.org.accounts :
    account.email if account.id == data.aws_caller_identity.current.account_id
  ])

  severity_order = ["INFORMATIONAL", "LOW", "MEDIUM", "HIGH", "CRITICAL"]

  notification_severity_labels = slice(
    local.severity_order,
    index(local.severity_order, upper(var.notification_min_severity)),
    length(local.severity_order),
  )
}
