# =============================================================================
# Organizational Units — CT Registration Module
#
# This module handles:
#   - Child OU creation (nested under root OUs passed in via var.root_ous)
#   - Baseline discovery (list-baselines + list-enabled-baselines via external)
#   - AWSControlTowerBaseline enablement on all root and child OUs
#   - BackupBaseline enablement on all OUs when var.enable_backup = true
#
# Root OUs are created in the root module (main.tf) to keep them available
# for module "control_tower" without circular dependencies.
# =============================================================================

# ---------------------------------------------------------------------------
# Auto-discover Control Tower baseline definitions and currently-enabled
# baselines in a single script (two API calls, one data source).
#
# Output keys:
#   baseline_ids              — JSON-encoded map of name -> ID token
#   identity_center_enabled_arn — ARN of the enabled IC baseline, or ""
# ---------------------------------------------------------------------------
data "external" "ct_baselines" {
  program = [
    "bash", "-c",
    <<-BASH
      python3 - <<'PYEOF'
import subprocess, json, sys

region = "${var.ct_home_region}"

# All baseline definitions: name -> {arn, id}
lb = json.loads(subprocess.check_output([
  "aws", "controltower", "list-baselines",
  "--region", region, "--output", "json"
]))
defs    = {b["name"]: b["arn"]                for b in lb["baselines"]}
def_ids = {b["name"]: b["arn"].split("/")[-1] for b in lb["baselines"]}

# All currently-enabled baselines: definition_arn -> enabled_arn
leb = json.loads(subprocess.check_output([
  "aws", "controltower", "list-enabled-baselines",
  "--region", region, "--output", "json"
]))
enabled = {eb["baselineIdentifier"]: eb["arn"] for eb in leb.get("enabledBaselines", [])}

# IdentityCenterEnabledBaselineArn — the only parameter AWSControlTowerBaseline accepts
ic_def_arn     = defs.get("IdentityCenterBaseline", "")
ic_enabled_arn = enabled.get(ic_def_arn, "") if ic_def_arn else ""

print(json.dumps({
  "baseline_ids":                json.dumps(def_ids),
  "identity_center_enabled_arn": ic_enabled_arn,
}))
PYEOF
    BASH
  ]
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
locals {
  # Decoded baseline name -> ID map
  baseline_ids = jsondecode(data.external.ct_baselines.result["baseline_ids"])

  # Full ARNs for the two OU-level baselines
  ct_baseline_arn     = "arn:aws:controltower:${var.ct_home_region}::baseline/${local.baseline_ids["AWSControlTowerBaseline"]}"
  backup_baseline_arn = "arn:aws:controltower:${var.ct_home_region}::baseline/${local.baseline_ids["BackupBaseline"]}"

  # IdentityCenterEnabledBaselineArn parameter — passed when IC is active
  ic_enabled_arn = data.external.ct_baselines.result["identity_center_enabled_arn"]

  ct_baseline_params = local.ic_enabled_arn != "" ? [
    {
      key   = "IdentityCenterEnabledBaselineArn"
      value = local.ic_enabled_arn
    }
  ] : []

  # Child OUs derived from the full map
  child_ous = { for k, v in var.organizational_units : k => v if v.parent_key != null }
}

# ---------------------------------------------------------------------------
# Child OUs — nested under root OUs passed in from the root module
# ---------------------------------------------------------------------------
resource "aws_organizations_organizational_unit" "child" {
  for_each = local.child_ous

  name      = each.value.name
  parent_id = var.root_ous[each.value.parent_key].id
}

# ---------------------------------------------------------------------------
# AWSControlTowerBaseline — root OUs
# ---------------------------------------------------------------------------
resource "aws_controltower_baseline" "root" {
  for_each = var.root_ous

  baseline_identifier = local.ct_baseline_arn
  baseline_version    = var.ct_baseline_version
  target_identifier   = each.value.arn

  dynamic "parameters" {
    for_each = local.ct_baseline_params
    content {
      key   = parameters.value.key
      value = parameters.value.value
    }
  }
}

# ---------------------------------------------------------------------------
# AWSControlTowerBaseline — child OUs
# ---------------------------------------------------------------------------
resource "aws_controltower_baseline" "child" {
  for_each = aws_organizations_organizational_unit.child

  baseline_identifier = local.ct_baseline_arn
  baseline_version    = var.ct_baseline_version
  target_identifier   = each.value.arn

  dynamic "parameters" {
    for_each = local.ct_baseline_params
    content {
      key   = parameters.value.key
      value = parameters.value.value
    }
  }

  depends_on = [aws_controltower_baseline.root]
}

# ---------------------------------------------------------------------------
# BackupBaseline — root OUs (only when enable_backup = true)
# ---------------------------------------------------------------------------
resource "aws_controltower_baseline" "root_backup" {
  for_each = var.enable_backup ? var.root_ous : {}

  baseline_identifier = local.backup_baseline_arn
  baseline_version    = var.ct_baseline_version
  target_identifier   = each.value.arn

  depends_on = [aws_controltower_baseline.root]
}

# ---------------------------------------------------------------------------
# BackupBaseline — child OUs (only when enable_backup = true)
# ---------------------------------------------------------------------------
resource "aws_controltower_baseline" "child_backup" {
  for_each = var.enable_backup ? aws_organizations_organizational_unit.child : {}

  baseline_identifier = local.backup_baseline_arn
  baseline_version    = var.ct_baseline_version
  target_identifier   = each.value.arn

  depends_on = [aws_controltower_baseline.child]
}
