# =============================================================================
# The pipeline
#
# Stage order:
#
#   source -> route -> [env stages] -> [promote approval] -> [next env stages] -> ...
#
# Every generated stage carries a before_entry condition with result SKIP, so
# the linear chain behaves like a branch. Skipped stages report as Skipped and
# their actions as Didn't Run.
#
# execution_mode = QUEUED is not optional here. The default, SUPERSEDED, cancels
# an in-flight execution when a new commit lands, which can abandon a run
# part-way through a layer. PARALLEL would run concurrent applies against the
# same state.
# =============================================================================

resource "aws_codepipeline" "this" {
  name          = local.pipeline_name
  role_arn      = local.codepipeline_role_arn
  pipeline_type = "V2"

  # See the note above. Do not change this without understanding the failure mode.
  execution_mode = "QUEUED"

  tags = var.tags

  artifact_store {
    type     = "S3"
    location = local.artifact_bucket
  }

  # Set to "full-sequential" when starting an execution by hand to run every
  # layer in order and ignore change detection. The router also treats any
  # manual start as full-sequential, so the console's "Release change" button
  # already behaves that way without setting anything.
  variable {
    name          = "FORCE_MODE"
    default_value = "auto"
    description   = "auto | full-sequential"
  }

  # --- source ---------------------------------------------------------------
  #
  # The configuration map (CODEBUILD_CLONE_REF, DetectChanges=false) is shared
  # with the rollback pipeline via local.source_config; see locals.tf.

  stage {
    name = "source"

    action {
      name             = "source"
      category         = "Source"
      owner            = "AWS"
      provider         = var.source_provider == "github" ? "CodeStarSourceConnection" : "CodeCommit"
      version          = "1"
      output_artifacts = ["source"]
      namespace        = "SourceVariables"
      run_order        = 1

      configuration = local.source_config
    }
  }

  # --- route ----------------------------------------------------------------

  stage {
    name = "route"

    action {
      name            = "route"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source"]
      namespace       = "Route"
      run_order       = 1

      configuration = {
        ProjectName = aws_codebuild_project.route.name
        EnvironmentVariables = jsonencode([
          { name = "EXECUTION_ID", value = "#{codepipeline.PipelineExecutionId}", type = "PLAINTEXT" },
          { name = "COMMIT_ID", value = "#{SourceVariables.CommitId}", type = "PLAINTEXT" },
          { name = "FORCE_MODE", value = "#{variables.FORCE_MODE}", type = "PLAINTEXT" },
        ])
      }
    }
  }

  # --- generated environment stages -----------------------------------------

  dynamic "stage" {
    for_each = local.stages

    content {
      name = stage.value.name

      before_entry {
        condition {
          result = "SKIP"

          dynamic "rule" {
            for_each = stage.value.checks

            content {
              name = rule.value.name

              rule_type_id {
                category = "Rule"
                owner    = "AWS"
                provider = "VariableCheck"
                version  = "1"
              }

              configuration = {
                Variable = rule.value.variable
                Value    = rule.value.value
                Operator = rule.value.operator
              }
            }
          }
        }
      }

      dynamic "action" {
        for_each = stage.value.actions

        content {
          name            = action.value.name
          category        = action.value.category
          owner           = "AWS"
          provider        = action.value.provider
          version         = "1"
          run_order       = action.value.run_order
          namespace       = action.value.namespace
          input_artifacts = action.value.category == "Approval" ? [] : ["source"]
          configuration   = action.value.configuration
        }
      }
    }
  }

  # --- push trigger (github) ------------------------------------------------
  #
  # Only a change that can affect a deployed layer starts the pipeline: the
  # layer folders, the root Makefile, and buildspecs/. A push that touches only
  # documentation (.md anywhere), the cicd module, or any folder that is not
  # named after a layer does not start the pipeline at all. This is a guard, not
  # a router: it cannot route per layer, so the router still makes the per-layer
  # decision with better information (each layer's own last-applied commit, per
  # environment).
  #
  # The trigger is always present for the main pipeline, independent of manual
  # approvals: a push to the configured branch must start the pipeline even when
  # a run flows straight through to production. The rollback pipeline has no
  # trigger at all, in every mode.

  dynamic "trigger" {
    for_each = var.source_provider == "github" ? [1] : []

    content {
      provider_type = "CodeStarSourceConnection"

      git_configuration {
        source_action_name = "source"

        push {
          branches {
            includes = [var.branch]
          }

          # The includes list is the set of paths that can ever change what runs;
          # **/*.md subtracts documentation that lives inside those folders. Both
          # are glob patterns as documented for CodePipeline trigger filters.
          file_paths {
            includes = concat(
              [for layer in var.layers : "${layer}/**"],
              ["Makefile", "buildspecs/**"],
            )
            excludes = ["**/*.md"]
          }
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.source_provider != "github" || var.connection_arn != null
      error_message = "connection_arn is required when source_provider is \"github\"."
    }

    precondition {
      condition     = local.stage_count <= 50
      error_message = "This configuration would create more than 50 stages, which is CodePipeline's hard limit. Reduce the number of environments or layers."
    }

    precondition {
      condition     = length(distinct([for e in local.environments : e.name])) == length(local.environments)
      error_message = "Environment names must be unique across dev_environment, intermediate_environments and prod_environment."
    }
  }
}

# --- change detection for CodeCommit ----------------------------------------
#
# CodeConnections sources get a native trigger block. CodeCommit has no trigger
# support in a V2 pipeline, so change detection is an EventBridge rule. The
# alternative, PollForSourceChanges, is slower and counts against a separate
# account quota.
#
# Like the native trigger, the rule exists in every mode: change detection on
# the main pipeline is independent of manual approvals.

data "aws_iam_policy_document" "events_assume" {
  count = var.source_provider == "codecommit" ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "events" {
  count = var.source_provider == "codecommit" ? 1 : 0

  name               = "${local.pipeline_name}-events"
  assume_role_policy = data.aws_iam_policy_document.events_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy" "events" {
  count = var.source_provider == "codecommit" ? 1 : 0

  name = "start-pipeline"
  role = aws_iam_role.events[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "codepipeline:StartPipelineExecution"
      Resource = aws_codepipeline.this.arn
    }]
  })
}

resource "aws_cloudwatch_event_rule" "codecommit" {
  count = var.source_provider == "codecommit" ? 1 : 0

  name        = "${local.pipeline_name}-source"
  description = "Starts ${local.pipeline_name} when ${var.branch} changes."
  tags        = var.tags

  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Repository State Change"]
    resources   = ["arn:${local.partition}:codecommit:${local.region}:${local.account_id}:${var.repository_id}"]
    detail = {
      event         = ["referenceCreated", "referenceUpdated"]
      referenceType = ["branch"]
      referenceName = [var.branch]
    }
  })
}

resource "aws_cloudwatch_event_target" "codecommit" {
  count = var.source_provider == "codecommit" ? 1 : 0

  rule     = aws_cloudwatch_event_rule.codecommit[0].name
  arn      = aws_codepipeline.this.arn
  role_arn = aws_iam_role.events[0].arn
}
