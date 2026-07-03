# ==============================================================================
# SSM Parameters — Role Discovery
#
# Both hub and spoke modes publish role ARNs to the AFT management account
# so that roles can be discovered across accounts without hardcoding.
# ==============================================================================

# --- Hub mode: publish service role ARNs ---

resource "aws_ssm_parameter" "hub_account_id" {
  count = local.is_hub ? 1 : 0

  provider    = aws.aft-management
  name        = "/org/core/accounts/cicd"
  type        = "String"
  description = "Central CI/CD account ID"
  value       = data.aws_caller_identity.current.account_id
  tags        = var.tags
}

resource "aws_ssm_parameter" "codebuild_role" {
  count = local.is_hub ? 1 : 0

  provider    = aws.aft-management
  name        = "/org/cicd/service-roles/codebuild"
  type        = "String"
  description = "CodeBuild service role ARN in CICD account"
  value       = aws_iam_role.codebuild[0].arn
  tags        = var.tags
}

resource "aws_ssm_parameter" "codepipeline_role" {
  count = local.is_hub ? 1 : 0

  provider    = aws.aft-management
  name        = "/org/cicd/service-roles/codepipeline"
  type        = "String"
  description = "CodePipeline service role ARN in CICD account"
  value       = aws_iam_role.codepipeline[0].arn
  tags        = var.tags
}

resource "aws_ssm_parameter" "github_oidc_roles" {
  for_each = local.enable_github_oidc ? var.github_oidc_roles : {}

  provider    = aws.aft-management
  name        = "/org/cicd/service-roles/github-oidc/${each.key}"
  type        = "String"
  description = "GitHub OIDC role '${each.key}' ARN in CICD account"
  value       = aws_iam_role.github_oidc[each.key].arn
  tags        = var.tags
}

# --- Spoke mode: publish deployment role ARNs ---

resource "aws_ssm_parameter" "deployer_role" {
  count = local.is_spoke ? 1 : 0

  provider    = aws.aft-management
  name        = "/org/cicd/roles/${data.aws_caller_identity.current.account_id}/deployer"
  type        = "String"
  description = "Default CI/CD deployer role ARN for account ${data.aws_caller_identity.current.account_id}"
  value       = aws_iam_role.deployer[0].arn
  tags        = var.tags
}

resource "aws_ssm_parameter" "custom_roles" {
  for_each = local.is_spoke ? var.custom_deployment_roles : {}

  provider    = aws.aft-management
  name        = "/org/cicd/roles/${data.aws_caller_identity.current.account_id}/custom/${each.key}"
  type        = "String"
  description = "Custom CI/CD role '${each.key}' ARN for account ${data.aws_caller_identity.current.account_id}"
  value       = aws_iam_role.custom[each.key].arn
  tags        = var.tags
}
