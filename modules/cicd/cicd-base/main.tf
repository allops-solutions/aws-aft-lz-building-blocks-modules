# ==============================================================================
# CI/CD Module
#
# A versatile module that handles both sides of cross-account CI/CD:
#
#   deployment_type = "hub" (CICD account):
#     - GitHub OIDC provider + scoped IAM roles
#     - CodeBuild/CodePipeline service roles
#     - All roles get sts:AssumeRole to workload deployment roles
#
#   deployment_type = "spoke" (workload accounts):
#     - Default deployment role (AdministratorAccess) trusting CICD account
#     - Optional custom roles with restricted policies
#
# Both modes publish role ARNs to SSM in the AFT management account.
# ==============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  is_hub   = var.deployment_type == "hub"
  is_spoke = var.deployment_type == "spoke"

  enable_github_oidc = local.is_hub && length(var.github_oidc_roles) > 0

  # Architectural constants — not configurable
  deployer_role_name       = "cicd-deployer"
  deployer_role_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  codebuild_role_name      = "cicd-codebuild-deployer"
  codepipeline_role_name   = "cicd-codepipeline-service"
}

# ==============================================================================
# HUB MODE — GitHub Actions OIDC Provider
# ==============================================================================

resource "aws_iam_openid_connect_provider" "github" {
  count = local.enable_github_oidc ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
  tags            = var.tags
}

# ==============================================================================
# HUB MODE — GitHub OIDC Roles
# ==============================================================================

data "aws_iam_policy_document" "github_oidc_trust" {
  for_each = local.enable_github_oidc ? var.github_oidc_roles : {}

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github[0].arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [each.value.subject_filter]
    }
  }
}

resource "aws_iam_role" "github_oidc" {
  for_each = local.enable_github_oidc ? var.github_oidc_roles : {}

  name               = each.key
  assume_role_policy = data.aws_iam_policy_document.github_oidc_trust[each.key].json
  tags               = var.tags
}

data "aws_iam_policy_document" "github_oidc_assume_workloads" {
  for_each = local.enable_github_oidc ? var.github_oidc_roles : {}

  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::*:role/${local.deployer_role_name}"]
  }
}

resource "aws_iam_role_policy" "github_oidc_assume_workloads" {
  for_each = local.enable_github_oidc ? var.github_oidc_roles : {}

  name   = "assume-workload-deployment-roles"
  role   = aws_iam_role.github_oidc[each.key].name
  policy = data.aws_iam_policy_document.github_oidc_assume_workloads[each.key].json
}

resource "aws_iam_role_policy_attachment" "github_oidc_extra" {
  for_each = {
    for pair in flatten([
      for role_name, role_config in (local.enable_github_oidc ? var.github_oidc_roles : {}) : [
        for idx, policy_arn in role_config.policy_arns : {
          key        = "${role_name}-${idx}"
          role_name  = role_name
          policy_arn = policy_arn
        }
      ]
    ]) : pair.key => pair
  }

  role       = aws_iam_role.github_oidc[each.value.role_name].name
  policy_arn = each.value.policy_arn
}

# ==============================================================================
# HUB MODE — CodeBuild Service Role
# ==============================================================================

data "aws_iam_policy_document" "codebuild_trust" {
  count = local.is_hub ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codebuild" {
  count = local.is_hub ? 1 : 0

  name               = local.codebuild_role_name
  assume_role_policy = data.aws_iam_policy_document.codebuild_trust[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "codebuild_permissions" {
  count = local.is_hub ? 1 : 0

  statement {
    sid       = "AssumeWorkloadRoles"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::*:role/${local.deployer_role_name}"]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/*"]
  }

  statement {
    sid    = "PipelineArtifacts"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::*pipeline-artifacts*",
      "arn:aws:s3:::*pipeline-artifacts*/*",
    ]
  }

  statement {
    sid    = "SSMParameters"
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]
    resources = ["arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/org/cicd/*"]
  }

  statement {
    sid    = "KMSDecrypt"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:GenerateDataKey",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  count = local.is_hub ? 1 : 0

  name   = "codebuild-permissions"
  role   = aws_iam_role.codebuild[0].name
  policy = data.aws_iam_policy_document.codebuild_permissions[0].json
}

# ==============================================================================
# HUB MODE — CodePipeline Service Role
# ==============================================================================

data "aws_iam_policy_document" "codepipeline_trust" {
  count = local.is_hub ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  count = local.is_hub ? 1 : 0

  name               = local.codepipeline_role_name
  assume_role_policy = data.aws_iam_policy_document.codepipeline_trust[0].json
  tags               = var.tags
}

data "aws_iam_policy_document" "codepipeline_permissions" {
  count = local.is_hub ? 1 : 0

  statement {
    sid    = "ArtifactBucket"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::*pipeline-artifacts*",
      "arn:aws:s3:::*pipeline-artifacts*/*",
    ]
  }

  statement {
    sid    = "CodeBuild"
    effect = "Allow"
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PassCodeBuildRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.codebuild[0].arn]
  }

  statement {
    sid    = "CodeStarConnections"
    effect = "Allow"
    actions = [
      "codestar-connections:UseConnection",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CodeCommit"
    effect = "Allow"
    actions = [
      "codecommit:GetBranch",
      "codecommit:GetCommit",
      "codecommit:UploadArchive",
      "codecommit:GetUploadArchiveStatus",
      "codecommit:CancelUploadArchive",
      "codecommit:GetRepository",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  count = local.is_hub ? 1 : 0

  name   = "codepipeline-permissions"
  role   = aws_iam_role.codepipeline[0].name
  policy = data.aws_iam_policy_document.codepipeline_permissions[0].json
}

# ==============================================================================
# SPOKE MODE — Default Deployment Role
# ==============================================================================

data "aws_iam_policy_document" "trust_cicd_account" {
  count = local.is_spoke ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.cicd_account_id}:root"]
    }
  }
}

resource "aws_iam_role" "deployer" {
  count = local.is_spoke ? 1 : 0

  name               = local.deployer_role_name
  assume_role_policy = data.aws_iam_policy_document.trust_cicd_account[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "deployer" {
  count = local.is_spoke ? 1 : 0

  role       = aws_iam_role.deployer[0].name
  policy_arn = local.deployer_role_policy_arn
}

# ==============================================================================
# SPOKE MODE — Custom Deployment Roles
# ==============================================================================

resource "aws_iam_role" "custom" {
  for_each = local.is_spoke ? var.custom_deployment_roles : {}

  name                 = each.key
  assume_role_policy   = data.aws_iam_policy_document.trust_cicd_account[0].json
  permissions_boundary = each.value.permissions_boundary
  tags                 = var.tags
}

resource "aws_iam_role_policy_attachment" "custom" {
  for_each = {
    for pair in flatten([
      for role_name, role_config in (local.is_spoke ? var.custom_deployment_roles : {}) : [
        for idx, policy_arn in role_config.policy_arns : {
          key        = "${role_name}-${idx}"
          role_name  = role_name
          policy_arn = policy_arn
        }
      ]
    ]) : pair.key => pair
  }

  role       = aws_iam_role.custom[each.value.role_name].name
  policy_arn = each.value.policy_arn
}

resource "aws_iam_role_policy" "custom_inline" {
  for_each = {
    for name, config in (local.is_spoke ? var.custom_deployment_roles : {}) :
    name => config if config.inline_policy_json != null
  }

  name   = "${each.key}-inline"
  role   = aws_iam_role.custom[each.key].name
  policy = each.value.inline_policy_json
}
