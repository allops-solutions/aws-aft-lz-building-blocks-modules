# ==============================================================================
# CI/CD Module — Outputs
# ==============================================================================

# --- Hub mode outputs ---

output "codebuild_role_arn" {
  description = "ARN of the CodeBuild service role (hub mode only)."
  value       = local.is_hub ? aws_iam_role.codebuild[0].arn : null
}

output "codepipeline_role_arn" {
  description = "ARN of the CodePipeline service role (hub mode only)."
  value       = local.is_hub ? aws_iam_role.codepipeline[0].arn : null
}

output "github_oidc_role_arns" {
  description = "Map of GitHub OIDC role names to their ARNs (hub mode only)."
  value       = { for name, role in aws_iam_role.github_oidc : name => role.arn }
}

# --- Spoke mode outputs ---

output "deployer_role_arn" {
  description = "ARN of the default deployment role (spoke mode only). Role name is always 'cicd-deployer' with AdministratorAccess."
  value       = local.is_spoke ? aws_iam_role.deployer[0].arn : null
}

output "deployer_role_name" {
  description = "Name of the default deployment role. Hardcoded to 'cicd-deployer' — not configurable."
  value       = local.deployer_role_name
}

output "custom_role_arns" {
  description = "Map of custom deployment role names to their ARNs (spoke mode only)."
  value       = { for name, role in aws_iam_role.custom : name => role.arn }
}
