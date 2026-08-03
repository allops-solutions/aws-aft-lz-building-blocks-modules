# =============================================================================
# Rollback pipeline
#
# A separate pipeline, never triggered by a branch push, that plans and applies
# all layers for the production environment at a user-specified commit.
#
# To use it:
#   1. Open the CodePipeline console and select the rollback pipeline.
#   2. Press "Release change" and set the TARGET_COMMIT variable to the commit
#      you want to roll back to. An empty value is refused by the build scripts:
#      rollback must never run at branch HEAD.
#   3. Review the plan output, approve the apply, and the pipeline applies every
#      layer in reverse dependency order (services -> databases -> network). The
#      approval step is skipped when enable_manual_approvals is false.
#
# IMPORTANT: Do NOT use the source version override — it is unreliable with
# CodeStarSourceConnection. Instead, set TARGET_COMMIT in the pipeline
# variables section of the release dialog. The build scripts checkout that
# commit explicitly.
#
# The rollback works by running the plan and apply at the chosen commit — the
# code at that commit defines the desired state, and terraform apply reconciles
# the live infrastructure to match it. This includes destroying resources that
# were added after the target commit.
#
# Stages: source -> for each layer in reverse: plan -> [approve] -> apply
# The rollback pipeline has no trigger block and DetectChanges is false, so it
# is never started by a push regardless of enable_manual_approvals.
# =============================================================================

locals {
  # Namespaces are alphanumeric-only and unique within the pipeline (see
  # locals.tf). The rollback plan action exports PLAN_SUMMARY under its own
  # namespace so the approval message can show the rendered plan.
  rollback_namespace = { for l in var.layers : l =>
    "Plan${replace(title(l), "/[^A-Za-z0-9]/", "")}"
  }

  rollback_stages = flatten([
    for l in reverse(var.layers) : concat(
      [
        {
          name = "${var.prod_environment.name}-plan-${l}"
          actions = [{
            name      = "plan-${l}"
            namespace = local.rollback_namespace[l]
            category  = "Build"
            provider  = "CodeBuild"
            configuration = {
              ProjectName = aws_codebuild_project.plan.name
              EnvironmentVariables = jsonencode(concat(
                local.layer_action_env["${var.prod_environment.name}/${l}"],
                [
                  { name = "TARGET_COMMIT", value = "#{variables.TARGET_COMMIT}", type = "PLAINTEXT" },
                ],
              ))
            }
          }]
        },
      ],
      var.enable_manual_approvals ? [
        {
          name = "${var.prod_environment.name}-approve-${l}"
          actions = [{
            name      = "approve"
            namespace = null
            category  = "Approval"
            provider  = "Manual"
            configuration = merge(local.approval_base, {
              CustomData = "Rollback: apply plan for ${l} to commit #{variables.TARGET_COMMIT}?\n#{${local.rollback_namespace[l]}.PLAN_SUMMARY}"
            })
          }]
        },
      ] : [],
      [
        {
          name = "${var.prod_environment.name}-apply-${l}"
          actions = [{
            name      = "apply-${l}"
            namespace = null
            category  = "Build"
            provider  = "CodeBuild"
            configuration = {
              ProjectName = aws_codebuild_project.apply.name
              EnvironmentVariables = jsonencode(concat(
                local.layer_action_env["${var.prod_environment.name}/${l}"],
                [
                  { name = "APPLY_SAVED_PLAN", value = "true", type = "PLAINTEXT" },
                  { name = "TARGET_COMMIT", value = "#{variables.TARGET_COMMIT}", type = "PLAINTEXT" },
                ],
              ))
            }
          }]
        },
      ],
    )
  ])
}

resource "aws_codepipeline" "rollback" {
  name           = "${var.workload}-rollback-production-infrastructure"
  role_arn       = local.codepipeline_role_arn
  pipeline_type  = "V2"
  execution_mode = "QUEUED"
  tags           = var.tags

  artifact_store {
    type     = "S3"
    location = local.artifact_bucket
  }

  # Set TARGET_COMMIT in the release dialog's Variables section. The build
  # scripts checkout this commit explicitly before running terraform, and refuse
  # to run if it is left empty: a rollback at branch HEAD is not a rollback.
  variable {
    name          = "TARGET_COMMIT"
    default_value = ""
    description   = "Commit to roll back to. Required — the build refuses to run if left empty."
  }

  # ---------------------------------------------------------------------------
  # source
  # ---------------------------------------------------------------------------
  # No trigger block and DetectChanges is false, so no automatic runs — manual
  # release only. Always checks out the branch HEAD. TARGET_COMMIT is checked
  # out by the build scripts instead.

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

  # ---------------------------------------------------------------------------
  # generated per-layer stages
  #
  # For each layer in reverse dependency order: plan -> [approve] -> apply.
  # This ordering ensures the last layer (services) is planned, approved and
  # applied first, so the base layer (VPC) still exists when downstream layers
  # need to run. ROUTE_PLAN is deliberately not passed so every layer runs.
  # ---------------------------------------------------------------------------

  dynamic "stage" {
    for_each = local.rollback_stages

    content {
      name = stage.value.name

      dynamic "action" {
        for_each = stage.value.actions

        content {
          name            = action.value.name
          category        = action.value.category
          owner           = "AWS"
          provider        = action.value.provider
          version         = "1"
          namespace       = action.value.namespace
          input_artifacts = action.value.category == "Approval" ? [] : ["source"]
          configuration   = action.value.configuration
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.source_provider != "github" || var.connection_arn != null
      error_message = "connection_arn is required when source_provider is \"github\"."
    }
  }
}
