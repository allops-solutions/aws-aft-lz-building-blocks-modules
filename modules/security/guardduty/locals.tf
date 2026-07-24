locals {
  # ----------------------------------------------------------------------------
  # Identify top-level OUs managed by Control Tower (have at least one control).
  # Map of OU name -> OU ID for those that qualify.
  # ----------------------------------------------------------------------------
  ct_managed_ou_ids = {
    for name, controls in data.aws_controltower_controls.root_ous :
    name => data.aws_organizations_organizational_units.root.children[
      index(data.aws_organizations_organizational_units.root.children[*].name, name)
    ].id
    if length(controls.enabled_controls) > 0 && name != "Suspended"
  }

  # ----------------------------------------------------------------------------
  # Account discovery: all accounts from CT-managed OUs + management account,
  # minus excluded accounts and the delegated admin (managed separately).
  # ----------------------------------------------------------------------------
  all_discovered_accounts = toset(concat(
    flatten([
      for ou_name, accounts in data.aws_organizations_organizational_unit_descendant_accounts.ct_managed :
      [for acct in accounts.accounts : acct.id]
    ]),
    [data.aws_organizations_organization.org.master_account_id],
  ))

  excluded = toset(var.excluded_account_ids)

  member_account_ids = toset([
    for id in local.all_discovered_accounts :
    id if !contains(local.excluded, id) && id != var.delegated_admin_account_id
  ])

  # ----------------------------------------------------------------------------
  # Protection plan features map for aws_guardduty_organization_configuration_feature.
  # Built from individual boolean variables. Includes the deprecated
  # EKS_RUNTIME_MONITORING explicitly set to NONE to prevent Terraform drift.
  # ----------------------------------------------------------------------------
  organization_features = {
    S3_DATA_EVENTS         = var.s3_protection_enabled ? "ALL" : "NONE"
    EKS_AUDIT_LOGS         = var.eks_audit_logs_enabled ? "ALL" : "NONE"
    EBS_MALWARE_PROTECTION = var.ebs_malware_protection_enabled ? "ALL" : "NONE"
    RDS_LOGIN_EVENTS       = var.rds_protection_enabled ? "ALL" : "NONE"
    LAMBDA_NETWORK_LOGS    = var.lambda_protection_enabled ? "ALL" : "NONE"
    RUNTIME_MONITORING     = var.runtime_monitoring_enabled ? "ALL" : "NONE"
    AI_PROTECTION          = var.ai_protection_enabled ? "ALL" : "NONE"
    EKS_RUNTIME_MONITORING = "NONE"
  }

  # ----------------------------------------------------------------------------
  # Runtime Monitoring additional configuration — always included to prevent
  # force-replacement when toggling. Values are NONE when disabled.
  # Uses a list (not map) to control ordering — must match the order AWS returns
  # from the API (ECS_FARGATE, EC2, EKS) to prevent perpetual replacement.
  # EKS_RUNTIME_MONITORING (deprecated) only has EKS_ADDON_MANAGEMENT.
  # ----------------------------------------------------------------------------
  runtime_monitoring_additional = [
    {
      name        = "ECS_FARGATE_AGENT_MANAGEMENT"
      auto_enable = var.runtime_monitoring_enabled ? lookup(var.runtime_monitoring_configuration, "ECS_FARGATE_AGENT_MANAGEMENT", "ALL") : "NONE"
    },
    {
      name        = "EC2_AGENT_MANAGEMENT"
      auto_enable = var.runtime_monitoring_enabled ? lookup(var.runtime_monitoring_configuration, "EC2_AGENT_MANAGEMENT", "ALL") : "NONE"
    },
    {
      name        = "EKS_ADDON_MANAGEMENT"
      auto_enable = var.runtime_monitoring_enabled ? lookup(var.runtime_monitoring_configuration, "EKS_ADDON_MANAGEMENT", "ALL") : "NONE"
    },
  ]

  eks_runtime_monitoring_additional = [
    {
      name        = "EKS_ADDON_MANAGEMENT"
      auto_enable = "NONE"
    },
  ]
}
