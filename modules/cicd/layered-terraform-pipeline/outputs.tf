output "pipeline_name" {
  description = "Name of the CodePipeline pipeline."
  value       = aws_codepipeline.this.name
}

output "pipeline_arn" {
  description = "ARN of the CodePipeline pipeline."
  value       = aws_codepipeline.this.arn
}

output "stage_names" {
  description = "Stages in execution order. Useful for confirming the generated topology before applying."
  value       = concat(["source", "route"], [for s in local.stages : s.name])
}

output "codebuild_role_arn" {
  description = "ARN of the CodeBuild service role created by this pipeline."
  value       = aws_iam_role.codebuild.arn
}

output "codepipeline_role_arn" {
  description = "ARN of the CodePipeline service role created by this pipeline."
  value       = aws_iam_role.codepipeline.arn
}

output "deployer_role_arns" {
  description = "Role assumed in each target account, per environment."
  value       = { for e in local.environments : e.name => "arn:${local.partition}:iam::${e.account_id}:role/${var.deployer_role_name}" }
}

output "artifact_bucket" {
  description = "Bucket holding CodePipeline artifacts."
  value       = local.artifact_bucket
}

output "watermark_parameter_prefix" {
  description = "SSM prefix, in this account, where each layer's last-applied commit is recorded."
  value       = "${var.watermark_prefix}/${var.workload}"
}

output "codebuild_projects" {
  description = "The three CodeBuild projects backing the pipeline."
  value = {
    route = aws_codebuild_project.route.name
    plan  = aws_codebuild_project.plan.name
    apply = aws_codebuild_project.apply.name
  }
}

output "rollback_pipeline_name" {
  description = "Name of the rollback pipeline."
  value       = aws_codepipeline.rollback.name
}

output "rollback_pipeline_arn" {
  description = "ARN of the rollback pipeline."
  value       = aws_codepipeline.rollback.arn
}
