###############################################################################
# Landing Zone Pipeline
#
# Self-managing CodePipeline for the bootstrap repo (Control Tower + AFT + OUs).
# Lives in the AFT management account and reuses the existing CodeConnections
# (from SSM). CodeBuild assumes a cross-account role in the CT management
# account to run Terraform, since that's where the state and resources live.
#
# Layout (when enable_manual_approval = true, the default):
#   Source -> Plan -> Manual Approval -> Apply
#
# Layout (when enable_manual_approval = false):
#   Source -> Apply (combined plan + apply in one CodeBuild run)
#
# VCS provider is auto-detected from SSM (/aft/config/vcs/provider).
# Supports both GitHub (CodeStarSourceConnection) and CodeCommit.
###############################################################################

###############################################################################
# SSM Data Sources — VCS configuration published by AFT
###############################################################################

data "aws_ssm_parameter" "vcs_provider" {
  name = "/aft/config/vcs/provider"
}

data "aws_ssm_parameter" "codeconnections_arn" {
  count = local.is_codecommit ? 0 : 1
  name  = "/aft/config/vcs/codeconnections-connection-arn"
}

###############################################################################
# Locals
###############################################################################

locals {
  # VCS provider detection from SSM
  vcs_provider  = lower(trimspace(data.aws_ssm_parameter.vcs_provider.value))
  is_codecommit = local.vcs_provider == "codecommit"

  # GitHub org — use variable if provided, otherwise the customer_name prefix handles it
  github_username = var.github_username

  solution_name         = "custom-aft-landing-zone"
  repo_name             = "${var.customer_name}-aft-control-tower-account-setup"
  full_repo_id          = "${local.github_username}/${local.repo_name}"
  branch_name           = "main"
  terraform_version     = "1.15.0"
  tf_state_bucket       = var.tf_state_bucket != "" ? var.tf_state_bucket : "terraform-state-terraform-account-factory-${var.ct_management_account_id}"
  tf_state_key          = var.tf_state_key != "" ? var.tf_state_key : "${local.solution_name}/terraform.tfstate"
  ct_execution_role_arn = "arn:aws:iam::${var.ct_management_account_id}:role/${var.ct_management_role_name}"

  # CodeConnections ARN — only available for GitHub
  codeconnections_arn = local.is_codecommit ? null : data.aws_ssm_parameter.codeconnections_arn[0].value
}

###############################################################################
# CodeCommit repository data source (only when vcs_provider = codecommit)
###############################################################################

data "aws_codecommit_repository" "this" {
  count           = local.is_codecommit ? 1 : 0
  repository_name = local.repo_name
}

###############################################################################
# S3 bucket for pipeline artifacts (in AFT account)
###############################################################################

resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "${local.solution_name}-artifacts-"
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-artifacts"
    status = "Enabled"

    expiration {
      days = 14
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

###############################################################################
# CloudWatch log groups (in AFT account)
###############################################################################

resource "aws_cloudwatch_log_group" "plan" {
  count = var.enable_manual_approval ? 1 : 0

  name              = "/aws/codebuild/${local.solution_name}-plan"
  retention_in_days = 365

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "apply" {
  name              = "/aws/codebuild/${local.solution_name}-apply"
  retention_in_days = 365

  tags = var.tags
}

###############################################################################
# IAM Role for CodeBuild (in AFT account)
#
# This role is assumed by CodeBuild. It has permissions to:
#   1. Write logs and access the artifact bucket (local to AFT account)
#   2. Assume the cross-account execution role in the CT management account
###############################################################################

resource "aws_iam_role" "codebuild" {
  name = "${local.solution_name}-codebuild"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "codebuild.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${local.solution_name}-codebuild"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AssumeCtManagementRole"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = local.ct_execution_role_arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.ct_home_region}:${var.aft_management_account_id}:*"
      },
      {
        Sid    = "ArtifactBucket"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*"
        ]
      }
    ]
  })
}

###############################################################################
# CodeBuild — plan project (only created when manual approval is enabled)
###############################################################################

resource "aws_codebuild_project" "plan" {
  count = var.enable_manual_approval ? 1 : 0

  name          = "${local.solution_name}-plan"
  description   = "terraform plan for ${var.customer_name}-aft-control-tower-account-setup"
  build_timeout = 60
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_MEDIUM"
    image        = "aws/codebuild/amazonlinux2-aarch64-standard:4.0"
    type         = "ARM_CONTAINER"

    environment_variable {
      name  = "TERRAFORM_VERSION"
      value = local.terraform_version
    }
    environment_variable {
      name  = "BRANCH_NAME"
      value = local.branch_name
    }
    environment_variable {
      name  = "CT_EXECUTION_ROLE_ARN"
      value = local.ct_execution_role_arn
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

  tags = var.tags
}

###############################################################################
# CodeBuild — apply project
#
# When manual approval is enabled, this consumes the plan artifact and runs
# `terraform apply <plan>`. When disabled, it runs init+plan+apply in one go.
###############################################################################

resource "aws_codebuild_project" "apply" {
  name          = "${local.solution_name}-apply"
  description   = "terraform apply for ${var.customer_name}-aft-control-tower-account-setup"
  build_timeout = 120
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_MEDIUM"
    image        = "aws/codebuild/amazonlinux2-aarch64-standard:4.0"
    type         = "ARM_CONTAINER"

    environment_variable {
      name  = "TERRAFORM_VERSION"
      value = local.terraform_version
    }
    environment_variable {
      name  = "BRANCH_NAME"
      value = local.branch_name
    }
    environment_variable {
      name  = "CT_EXECUTION_ROLE_ARN"
      value = local.ct_execution_role_arn
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

  tags = var.tags
}

###############################################################################
# IAM Role for CodePipeline (in AFT account)
###############################################################################

resource "aws_iam_role" "pipeline" {
  name = "${local.solution_name}-pipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "codepipeline.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "pipeline" {
  name = "${local.solution_name}-pipeline"
  role = aws_iam_role.pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # CodeConnections permission — only for GitHub
      local.is_codecommit ? [] : [
        {
          Effect   = "Allow"
          Action   = "codestar-connections:UseConnection"
          Resource = local.codeconnections_arn
        }
      ],
      # CodeCommit permissions — only for CodeCommit
      local.is_codecommit ? [
        {
          Effect = "Allow"
          Action = [
            "codecommit:GetBranch",
            "codecommit:GetCommit",
            "codecommit:UploadArchive",
            "codecommit:GetUploadArchiveStatus",
            "codecommit:CancelUploadArchive"
          ]
          Resource = data.aws_codecommit_repository.this[0].arn
        }
      ] : [],
      [
        {
          Effect = "Allow"
          Action = [
            "codebuild:BatchGetBuilds",
            "codebuild:StartBuild"
          ]
          Resource = compact([
            aws_codebuild_project.apply.arn,
            var.enable_manual_approval ? aws_codebuild_project.plan[0].arn : null
          ])
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:PutObject",
            "s3:GetBucketVersioning",
            "s3:ListBucket"
          ]
          Resource = [
            aws_s3_bucket.artifacts.arn,
            "${aws_s3_bucket.artifacts.arn}/*"
          ]
        }
      ]
    )
  })
}

###############################################################################
# CodePipeline V2 (in AFT account)
###############################################################################

resource "aws_codepipeline" "this" {
  name           = local.solution_name
  role_arn       = aws_iam_role.pipeline.arn
  pipeline_type  = "V2"
  execution_mode = "SUPERSEDED"

  artifact_store {
    location = aws_s3_bucket.artifacts.id
    type     = "S3"
  }

  # Trigger for GitHub (V2 pipelines require explicit triggers)
  dynamic "trigger" {
    for_each = !local.is_codecommit && var.enable_pipeline_trigger ? [1] : []
    content {
      provider_type = "CodeStarSourceConnection"

      git_configuration {
        source_action_name = "source"

        push {
          branches {
            includes = [local.branch_name]
          }
        }
      }
    }
  }

  stage {
    name = "Source"

    action {
      name             = "source"
      category         = "Source"
      owner            = "AWS"
      provider         = local.is_codecommit ? "CodeCommit" : "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      namespace        = "SourceVariables"

      configuration = local.is_codecommit ? {
        RepositoryName       = local.repo_name
        BranchName           = local.branch_name
        PollForSourceChanges = false
        OutputArtifactFormat = "CODE_ZIP"
      } : {
        ConnectionArn        = local.codeconnections_arn
        FullRepositoryId     = local.full_repo_id
        BranchName           = local.branch_name
        DetectChanges        = false
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

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
          ProjectName = aws_codebuild_project.plan[0].name
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

        timeout_in_minutes = 30
      }
    }
  }

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
        ProjectName = aws_codebuild_project.apply.name
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

  tags = var.tags
}

###############################################################################
# EventBridge trigger for CodeCommit (replaces the V2 trigger block)
###############################################################################

resource "aws_cloudwatch_event_rule" "codecommit_trigger" {
  count = local.is_codecommit && var.enable_pipeline_trigger ? 1 : 0

  name        = "${local.solution_name}-${local.branch_name}-trigger"
  description = "Trigger pipeline on push to ${local.branch_name}"

  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Repository State Change"]
    resources   = [data.aws_codecommit_repository.this[0].arn]
    detail = {
      event         = ["referenceCreated", "referenceUpdated"]
      referenceType = ["branch"]
      referenceName = [local.branch_name]
    }
  })

  tags = var.tags
}

resource "aws_iam_role" "events" {
  count = local.is_codecommit && var.enable_pipeline_trigger ? 1 : 0

  name = "${local.solution_name}-events"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "events" {
  count = local.is_codecommit && var.enable_pipeline_trigger ? 1 : 0

  name = "${local.solution_name}-events"
  role = aws_iam_role.events[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "codepipeline:StartPipelineExecution"
        Resource = aws_codepipeline.this.arn
      }
    ]
  })
}

resource "aws_cloudwatch_event_target" "codecommit_trigger" {
  count = local.is_codecommit && var.enable_pipeline_trigger ? 1 : 0

  rule     = aws_cloudwatch_event_rule.codecommit_trigger[0].name
  role_arn = aws_iam_role.events[0].arn
  arn      = aws_codepipeline.this.arn
}

###############################################################################
# IAM Role in CT Management Account (cross-account execution role)
#
# This role lives in the CT management account and is assumed by the CodeBuild
# role in the AFT account. It has AdministratorAccess because Terraform manages
# Control Tower, Organizations, AFT, and IAM from this account.
###############################################################################

resource "aws_iam_role" "ct_execution" {
  provider = aws.org-management

  name = var.ct_management_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.codebuild.arn }
        Action    = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:PrincipalAccount" = var.aft_management_account_id
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ct_execution_admin" {
  provider = aws.org-management

  role       = aws_iam_role.ct_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
