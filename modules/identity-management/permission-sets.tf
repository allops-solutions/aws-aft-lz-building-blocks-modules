# ==============================================================================
# Permission sets
#
# Created from var.permission_sets. The map key is the permission set name as
# it appears in Identity Center — no organisation prefix.
# ==============================================================================

resource "aws_ssoadmin_permission_set" "this" {
  for_each = var.permission_sets

  instance_arn     = local.instance_arn
  name             = each.key
  description      = each.value.description
  session_duration = each.value.session_duration

  tags = {
    managed-by = "aft-aws-permission-sets"
    role       = each.key
  }
}

locals {
  managed_policy_attachments = flatten([
    for ps_key, ps in var.permission_sets : [
      for policy_arn in ps.managed_policies : {
        key        = "${ps_key}-${policy_arn}"
        ps_key     = ps_key
        policy_arn = policy_arn
      }
    ]
  ])

  # Map permission set keys to their ARNs for use in assignments.
  permission_set_arns = {
    for ps_key, ps in var.permission_sets :
    ps_key => aws_ssoadmin_permission_set.this[ps_key].arn
  }
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = {
    for a in local.managed_policy_attachments : a.key => a
  }

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.ps_key].arn
  managed_policy_arn = each.value.policy_arn
}

resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  for_each = {
    for ps_key, ps in var.permission_sets : ps_key => ps
    if ps.inline_policy != ""
  }

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  inline_policy      = each.value.inline_policy
}
