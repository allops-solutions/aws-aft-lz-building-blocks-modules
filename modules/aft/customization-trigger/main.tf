###############################################################################
# Customization Trigger Pipeline
#
# A CodePipeline V2 that watches the global-customizations and
# account-customizations repos for pushes and automatically invokes the
# aft-invoke-customizations Step Function with {"include": [{"type": "all"}]}.
#
# Runs in the AFT management account (default provider).
# This is additive to the AFT module — it does not modify any AFT resources.
###############################################################################

locals {
  aft_sfn_arn = "arn:aws:states:${var.ct_home_region}:${var.aft_management_account_id}:stateMachine:aft-invoke-customizations"
}

# Read the CodeConnections ARN from SSM (created by the AFT module)
data "aws_ssm_parameter" "codeconnections_arn" {
  name = "/aft/config/vcs/codeconnections-connection-arn"
}

###############################################################################
# IAM Role for CodeBuild — invoke Step Function
###############################################################################

resource "aws_iam_role" "codebuild" {
  name = "custom-aft-customization-trigger-codebuild"

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
  name = "custom-aft-customization-trigger-codebuild"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "states:StartExecution"
        Resource = local.aft_sfn_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.ct_home_region}:${var.aft_management_account_id}:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning"
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
# CodeBuild Project — invokes the Step Function
###############################################################################

resource "aws_codebuild_project" "this" {
  name          = "custom-aft-customization-trigger"
  description   = "Invokes aft-invoke-customizations Step Function on repo push"
  build_timeout = 15
  service_role  = aws_iam_role.codebuild.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_LAMBDA_1GB"
    image        = "aws/codebuild/amazonlinux-aarch64-lambda-standard:python3.14"
    type         = "ARM_LAMBDA_CONTAINER"

    environment_variable {
      name  = "SFN_ARN"
      value = local.aft_sfn_arn
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<-BUILDSPEC
      version: 0.2
      phases:
        build:
          commands:
            - |
              aws stepfunctions start-execution \
                --state-machine-arn "$SFN_ARN" \
                --input '{"include": [{"type": "all"}]}'
              echo "Successfully triggered aft-invoke-customizations"
    BUILDSPEC
  }

  tags = var.tags
}

###############################################################################
# IAM Role for CodePipeline
###############################################################################

resource "aws_iam_role" "pipeline" {
  name = "custom-aft-customization-trigger-pipeline"

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
  name = "custom-aft-customization-trigger-pipeline"
  role = aws_iam_role.pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "codestar-connections:UseConnection"
        Resource = data.aws_ssm_parameter.codeconnections_arn.value
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = aws_codebuild_project.this.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:GetBucketVersioning"
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
# S3 Bucket for Pipeline Artifacts
###############################################################################

resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "custom-aft-customization-trigger-"
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-artifacts"
    status = "Enabled"

    expiration {
      days = 1
    }
  }
}

###############################################################################
# CodePipeline V2 — watches global and account customization repos
###############################################################################

resource "aws_codepipeline" "this" {
  name          = "custom-aft-customization-trigger"
  role_arn      = aws_iam_role.pipeline.arn
  pipeline_type = "V2"

  artifact_store {
    location = aws_s3_bucket.artifacts.id
    type     = "S3"
  }

  trigger {
    provider_type = "CodeStarSourceConnection"

    git_configuration {
      source_action_name = "aft-global-customizations"

      push {
        branches {
          includes = ["main"]
        }
      }
    }
  }

  trigger {
    provider_type = "CodeStarSourceConnection"

    git_configuration {
      source_action_name = "aft-account-customizations"

      push {
        branches {
          includes = ["main"]
        }
      }
    }
  }

  stage {
    name = "Source"

    action {
      name             = "aft-global-customizations"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_global"]

      configuration = {
        ConnectionArn        = data.aws_ssm_parameter.codeconnections_arn.value
        FullRepositoryId     = "${var.github_username}/${var.customer_name}-aft-global-customizations"
        BranchName           = "main"
        DetectChanges        = false
        OutputArtifactFormat = "CODE_ZIP"
      }
    }

    action {
      name             = "aft-account-customizations"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_account"]

      configuration = {
        ConnectionArn        = data.aws_ssm_parameter.codeconnections_arn.value
        FullRepositoryId     = "${var.github_username}/${var.customer_name}-aft-account-customizations"
        BranchName           = "main"
        DetectChanges        = false
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Invoke-Customizations"

    action {
      name            = "Trigger-StepFunction"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["source_global"]
      version         = "1"

      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  tags = var.tags
}
