###############################################################################
# Break-Glass Access
#
# Emergency access for when IAM Identity Center and/or the external IdP are
# unavailable. Provides a single, dormant, MFA-protected, console-only IAM user
# in the Control Tower MANAGEMENT account that can switch-role into
# AWSControlTowerExecution in every Control Tower-managed account.
#
# ALL resources in this module are deployed exclusively in us-east-1. Console
# sign-in events are global and only land in us-east-1, so the EventBridge rules,
# SNS topic, CloudTrail trail, bookmarks bucket, and Lambda all live there.
#
# This module is an optional AFT add-on. It is instantiated from the
# aft-management customization and creates all resources in the management
# account through the org-management provider alias (which assumes
# AWSAFTExecution there, configured for us-east-1).
#
# Resource breakdown:
#   iam.tf         break-glass user + self-service MFA + MFA-gated assume-role
#   bookmarks.tf   private S3 bucket holding the rendered switch-role page
#   lambda.tf      refresh Lambda (lists CT-managed accounts) + EventBridge triggers
#   monitoring.tf  SNS + email + EventBridge rules that alert on ANY use
#
# Design rationale and the operational runbook live in BREAK_GLASS.md.
###############################################################################
