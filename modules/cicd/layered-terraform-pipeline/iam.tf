# =============================================================================
# IAM
#
# Three identities are involved:
#
#   codepipeline role   orchestrates; starts builds, reads the source
#   codebuild role      runs the router, plans and applies; assumes into targets
#   deployer role       the identity Terraform actually runs as, in the target
#                       account. Normally created by cicd-base in spoke mode;
#                       created here when create_deployment_roles is true.
#
# Nothing sets assume_role in a Terraform backend or provider block. The build
# assumes the deployer role and exports credentials to the environment, so the
# same configuration works unchanged on a developer's laptop under their own
# credentials.
# =============================================================================
locals {
  create_codebuild_role    = var.codebuild_role_arn == null
  create_codepipeline_role = var.codepipeline_role_arn == null

  codebuild_role_arn    = var.codebuild_role_arn != null ? var.codebuild_role_arn : aws_iam_role.codebuild[0].arn
  codepipeline_role_arn = var.codepipeline_role_arn != null ? var.codepipeline_role_arn : aws_iam_role.codepipeline[0].arn

  connection_arns = var.source_provider == "github" ? [var.connection_arn] : []

  # Parameter names are "${watermark_prefix}/${workload}/<env>/<layer>/last-applied-commit",
  # so the ARN path is "parameter" followed by the prefix. Matching the prefix
  # exactly and its descendants keeps the codebuild role scoped to this workload.
  watermark_arns = [
    "arn:${local.partition}:ssm:${local.region}:${local.account_id}:parameter${var.watermark_prefix}",
    "arn:${local.partition}:ssm:${local.region}:${local.account_id}:parameter${var.watermark_prefix}/*",
  ]
}

# --- CodeBuild service role -------------------------------------------------

data "aws_iam_policy_document" "codebuild_assume" {
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
  count = local.create_codebuild_role ? 1 : 0

  name               = "${local.pipeline_name}-codebuild"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid    = "Logs"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = [
      "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/codebuild/${local.pipeline_name}-*",
      "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/codebuild/${local.pipeline_name}-*:*",
    ]
  }

  statement {
    sid    = "PipelineArtifacts"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]

    resources = [
      "arn:${local.partition}:s3:::${local.artifact_bucket}",
      "arn:${local.partition}:s3:::${local.artifact_bucket}/*",
    ]
  }

  # The router reads watermarks for every environment; each apply writes its own
  # after a successful run. Watermarks live in THIS account so the router needs
  # no cross-account access to make its decision.
  statement {
    sid    = "Watermarks"
    effect = "Allow"

    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:PutParameter",
      "ssm:AddTagsToResource",
    ]

    resources = local.watermark_arns
  }

  # Reading its own execution's trigger type is how the router knows a human
  # pressed "Release change" and therefore wants a full sequential run.
  statement {
    sid    = "ReadOwnExecution"
    effect = "Allow"

    actions = [
      "codepipeline:GetPipelineExecution",
      "codepipeline:ListPipelineExecutions",
    ]

    resources = ["arn:${local.partition}:codepipeline:${local.region}:${local.account_id}:${local.pipeline_name}"]
  }

  # The per-layer JUnit reports are the failure channel: CodePipeline only
  # publishes an action's exported variables after it succeeds, but report files
  # are uploaded even when the BUILD phase fails. The report groups are
  # auto-created from the buildspecs' `reports:` section as
  # <project>-layer-status, so scope to this pipeline's projects only.
  statement {
    sid    = "TestReports"
    effect = "Allow"

    actions = [
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases",
    ]

    resources = ["arn:${local.partition}:codebuild:${local.region}:${local.account_id}:report-group/${local.pipeline_name}-*"]
  }

  statement {
    sid       = "AssumeDeployer"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = local.deployer_role_arns
  }

  dynamic "statement" {
    for_each = local.connection_arns

    content {
      sid    = "UseCodeConnection"
      effect = "Allow"

      actions = [
        "codestar-connections:UseConnection",
        "codestar-connections:GetConnection",
        "codeconnections:UseConnection",
        "codeconnections:GetConnection",
        "codeconnections:GetConnectionToken",
      ]

      resources = [statement.value]

      # UseConnection is what talks to the provider. Unscoped it grants access
      # to every repository the connection can reach, so scope it to the
      # configured repository and to the Git protocol actions the builds need.
      # BranchName is deliberately not used: the git protocol (full clone via
      # CODEBUILD_CLONE_REF) sends no branch name, so it would break the builds.
      condition {
        test     = "StringEquals"
        variable = "codeconnections:FullRepositoryId"
        values   = [var.repository_id]
      }

      condition {
        test     = "StringEquals"
        variable = "codeconnections:ProviderAction"
        values   = ["GitPull"]
      }
    }
  }
}

resource "aws_iam_role_policy" "codebuild" {
  count = local.create_codebuild_role ? 1 : 0

  name   = "pipeline"
  role   = aws_iam_role.codebuild[0].id
  policy = data.aws_iam_policy_document.codebuild.json
}

# --- CodePipeline service role ----------------------------------------------

data "aws_iam_policy_document" "codepipeline_assume" {
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
  count = local.create_codepipeline_role ? 1 : 0

  name               = "${local.pipeline_name}-codepipeline"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    sid    = "Artifacts"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObject",
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]

    resources = [
      "arn:${local.partition}:s3:::${local.artifact_bucket}",
      "arn:${local.partition}:s3:::${local.artifact_bucket}/*",
    ]
  }

  statement {
    sid    = "StartBuilds"
    effect = "Allow"

    actions = [
      "codebuild:StartBuild",
      "codebuild:StopBuild",
      "codebuild:BatchGetBuilds",
    ]

    resources = [
      aws_codebuild_project.route.arn,
      aws_codebuild_project.plan.arn,
      aws_codebuild_project.apply.arn,
    ]
  }

  dynamic "statement" {
    for_each = local.connection_arns

    content {
      sid    = "UseCodeConnection"
      effect = "Allow"

      actions = [
        "codestar-connections:UseConnection",
        "codeconnections:UseConnection",
      ]

      resources = [statement.value]

      # The source stage reads the configured branch: GetBranch for the latest
      # commit, GetCommit for the commit the build runs, GenerateReferenceLink
      # for the console link. All three requests carry the repository id, so the
      # connection grant is scoped to this repository alone. BranchName is not
      # usable here: GetCommit and GenerateReferenceLink send no branch name.
      condition {
        test     = "StringEquals"
        variable = "codeconnections:FullRepositoryId"
        values   = [var.repository_id]
      }

      condition {
        test     = "StringEquals"
        variable = "codeconnections:ProviderAction"
        values   = ["GetBranch", "GetCommit", "GenerateReferenceLink"]
      }
    }
  }

  dynamic "statement" {
    for_each = var.source_provider == "codecommit" ? [1] : []

    content {
      sid    = "ReadCodeCommit"
      effect = "Allow"

      actions = [
        "codecommit:GetBranch",
        "codecommit:GetCommit",
        "codecommit:GetRepository",
        "codecommit:GetUploadArchiveStatus",
        "codecommit:UploadArchive",
      ]

      resources = ["arn:${local.partition}:codecommit:${local.region}:${local.account_id}:${var.repository_id}"]
    }
  }
}

resource "aws_iam_role_policy" "codepipeline" {
  count = local.create_codepipeline_role ? 1 : 0

  name   = "pipeline"
  role   = aws_iam_role.codepipeline[0].id
  policy = data.aws_iam_policy_document.codepipeline.json
}

# --- Deployer role (self-contained deployment) ------------------------------
#
# Created only when create_deployment_roles is true. Terraform can create it
# only where its provider points, which is why this mode requires every
# environment to be the current account.

data "aws_iam_policy_document" "deployer_assume" {
  count = var.create_deployment_roles ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [local.codebuild_role_arn]
    }
  }
}

resource "aws_iam_role" "deployer" {
  count = var.create_deployment_roles ? 1 : 0

  name               = var.deployer_role_name
  assume_role_policy = data.aws_iam_policy_document.deployer_assume[0].json
  tags               = var.tags

  lifecycle {
    precondition {
      condition     = alltrue([for e in local.environments : e.account_id == local.account_id])
      error_message = "create_deployment_roles = true requires every environment to point at the current account. Terraform can only create the deployer role where its provider is pointed; for real multi-account setups let cicd-base create it in each spoke."
    }
  }
}

resource "aws_iam_role_policy_attachment" "deployer" {
  for_each = var.create_deployment_roles ? toset(var.deployment_role_policy_arns) : toset([])

  role       = aws_iam_role.deployer[0].name
  policy_arn = each.value
}
