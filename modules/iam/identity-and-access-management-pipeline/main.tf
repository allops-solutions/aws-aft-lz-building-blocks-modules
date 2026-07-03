# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

# Codeconnection for github
resource "aws_codeconnections_connection" "github" {
  count         = local.vcs.is_github ? 1 : 0
  name          = "${var.solution_name}-conn"
  provider_type = "GitHub"
}

# Codeconnection for github enterprise
resource "aws_codeconnections_connection" "githubenterprise" {
  count    = local.vcs.is_github_enterprise ? 1 : 0
  name     = "${var.solution_name}-gh-ent"
  host_arn = aws_codeconnections_host.githubenterprise[0].arn
}

# Codeconnection host for github enterprise
resource "aws_codeconnections_host" "githubenterprise" {
  count             = local.vcs.is_github_enterprise ? 1 : 0
  name              = "${var.solution_name}-gh-ent-host"
  provider_endpoint = var.github_enterprise_url
  provider_type     = "GitHubEnterpriseServer"

  dynamic "vpc_configuration" {
    for_each = var.enable_vpc_config ? [true] : []
    content {
      security_group_ids = var.vpc_config.security_groups
      subnet_ids         = var.vpc_config.subnets
      vpc_id             = var.vpc_config.vpc_id
    }
  }
}

resource "aws_codecommit_repository" "pipeline" {
  #checkov:skip=CKV2_AWS_37: An approval rule can be set up after the deployment.
  count = local.vcs.is_codecommit ? 1 : 0

  repository_name = var.repository_name
  description     = "Identity and Access Management Pipeline repository"
  default_branch  = var.branch_name
  tags            = var.tags
}

#-------------------------------------------------------------

# Plan project - only created when manual approval is enabled
resource "aws_codebuild_project" "plan" {
  count = var.enable_manual_approval ? 1 : 0

  name           = "${var.solution_name}-plan"
  service_role   = aws_iam_role.codebuild.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-aarch64-standard:4.0"
    type         = "ARM_CONTAINER"
    environment_variable {
      name  = "BRANCH_NAME"
      value = var.branch_name
    }
    environment_variable {
      name  = "TERRAFORM_VERSION"
      value = var.terraform_version
    }
    environment_variable {
      name  = "TF_BACKEND_BUCKET"
      value = aws_s3_bucket.tf_backend.bucket
    }
    environment_variable {
      name  = "TF_BACKEND_REGION"
      value = data.aws_region.current.name
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = data.local_file.buildspec_plan.content
  }
  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.plan[0].name
    }
  }
  dynamic "vpc_config" {
    for_each = var.enable_vpc_config ? [true] : []
    content {
      security_group_ids = var.vpc_config.security_groups
      subnets            = var.vpc_config.subnets
      vpc_id             = var.vpc_config.vpc_id
    }
  }
  tags = var.tags
}

# Apply project - uses apply-only buildspec when approval is enabled,
# combined (plan+apply) buildspec when approval is disabled.
resource "aws_codebuild_project" "apply" {
  name           = "${var.solution_name}-apply"
  service_role   = aws_iam_role.codebuild.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-aarch64-standard:4.0"
    type         = "ARM_CONTAINER"
    environment_variable {
      name  = "BRANCH_NAME"
      value = var.branch_name
    }
    environment_variable {
      name  = "TERRAFORM_VERSION"
      value = var.terraform_version
    }
    environment_variable {
      name  = "TF_BACKEND_BUCKET"
      value = aws_s3_bucket.tf_backend.bucket
    }
    environment_variable {
      name  = "TF_BACKEND_REGION"
      value = data.aws_region.current.name
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = var.enable_manual_approval ? data.local_file.buildspec_apply.content : data.local_file.buildspec_combined.content
  }
  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.apply.name
    }
  }
  dynamic "vpc_config" {
    for_each = var.enable_vpc_config ? [true] : []
    content {
      security_group_ids = var.vpc_config.security_groups
      subnets            = var.vpc_config.subnets
      vpc_id             = var.vpc_config.vpc_id
    }
  }
  tags = var.tags
}

resource "aws_cloudwatch_log_group" "plan" {
  count = var.enable_manual_approval ? 1 : 0

  name              = "/aws/codebuild/${var.solution_name}-plan"
  retention_in_days = 365
}

resource "aws_cloudwatch_log_group" "apply" {
  name              = "/aws/codebuild/${var.solution_name}-apply"
  retention_in_days = 365
}

resource "aws_codepipeline" "this" {
  name          = var.solution_name
  role_arn      = aws_iam_role.codepipeline.arn
  pipeline_type = "V2"
  artifact_store {
    location = aws_s3_bucket.pipeline.bucket
    type     = "S3"
  }
  stage {
    name = "Source"
    action {
      name             = "source"
      category         = "Source"
      owner            = "AWS"
      provider         = local.vcs.is_codecommit ? "CodeCommit" : "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      namespace        = "SourceVariables"
      configuration = local.vcs.is_codecommit ? {
        RepositoryName       = aws_codecommit_repository.pipeline[0].repository_name
        BranchName           = var.branch_name
        PollForSourceChanges = false
        OutputArtifactFormat = "CODE_ZIP"
        } : {
        ConnectionArn        = local.codeconnection_arn
        FullRepositoryId     = var.repository_name
        BranchName           = var.branch_name
        OutputArtifactFormat = "CODEBUILD_CLONE_REF"
      }
    }
  }

  # Plan stage - only when manual approval is enabled
  dynamic "stage" {
    for_each = var.enable_manual_approval ? [1] : []
    content {
      name = "Plan"
      action {
        name             = "terraform-plan"
        category         = "Build"
        owner            = "AWS"
        provider         = "CodeBuild"
        version          = "1"
        input_artifacts  = ["source_output"]
        output_artifacts = ["plan_output"]
        configuration = {
          PrimarySource = "source"
          ProjectName   = aws_codebuild_project.plan[0].name
          EnvironmentVariables = jsonencode([
            {
              name  = "GIT_BRANCH"
              type  = "PLAINTEXT"
              value = "#{SourceVariables.BranchName}"
            }
          ])
        }
      }
    }
  }

  # Manual approval stage - only when enabled
  dynamic "stage" {
    for_each = var.enable_manual_approval ? [1] : []
    content {
      name = "Approval"
      action {
        name     = "manual-approval"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"
        configuration = {
          CustomData = "Review the Terraform plan output and approve to proceed with apply."
        }
      }
    }
  }

  # Apply stage - uses plan_output when approval is enabled, source_output otherwise
  stage {
    name = "Apply"
    action {
      name            = "terraform-apply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = [var.enable_manual_approval ? "plan_output" : "source_output"]
      configuration = {
        PrimarySource = "source"
        ProjectName   = aws_codebuild_project.apply.name
        EnvironmentVariables = jsonencode([
          {
            name  = "GIT_BRANCH"
            type  = "PLAINTEXT"
            value = "#{SourceVariables.BranchName}"
          }
        ])
      }
    }
  }

  # Trigger for GitHub/GitHub Enterprise (V2 pipelines require explicit triggers)
  dynamic "trigger" {
    for_each = !local.vcs.is_codecommit ? [1] : []
    content {
      provider_type = "CodeStarSourceConnection"
      git_configuration {
        source_action_name = "source"
        push {
          branches {
            includes = [var.branch_name]
          }
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "this" {
  count = local.vcs.is_codecommit ? 1 : 0

  name        = "${var.solution_name}-${var.branch_name}-branch-trigger"
  description = "Rule to trigger the CodePipeline based on code changes"
  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Repository State Change"]
    resources   = [aws_codecommit_repository.pipeline[0].arn]
    detail = {
      event = [
        "referenceCreated",
        "referenceUpdated"
      ]
      referenceType = ["branch"]
      referenceName = [var.branch_name]
    }
  })
}

resource "aws_cloudwatch_event_target" "this" {
  count = local.vcs.is_codecommit ? 1 : 0

  rule     = aws_cloudwatch_event_rule.this[0].name
  role_arn = aws_iam_role.start_pipeline.arn
  arn      = aws_codepipeline.this.arn
}
