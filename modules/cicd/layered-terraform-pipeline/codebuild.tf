# =============================================================================
# CodeBuild projects
#
# Three projects only, regardless of how many environments or layers exist.
# Everything that varies per environment or per layer is passed as action-level
# environment variables from the pipeline, which keeps the resource count flat
# and means adding an environment creates no new build projects.
# =============================================================================

# --- router ------------------------------------------------------------------
#
# Runs on Lambda compute: sub-second start-up, and the curated Lambda images
# include git and the AWS CLI v2, which is everything the router needs.
#
# build_timeout and queued_timeout are deliberately absent -- Lambda compute
# rejects custom timeouts and caps runtime at 15 minutes.

resource "aws_codebuild_project" "route" {
  name         = "${local.pipeline_name}-route"
  description  = "Decides which layers run, in which order, for each environment."
  service_role = local.codebuild_role_arn
  tags         = var.tags

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    type         = var.route_compute.environment_type
    compute_type = var.route_compute.compute_type
    image        = var.route_compute.image

    environment_variable {
      name  = "WORKLOAD"
      value = var.workload
    }

    environment_variable {
      name  = "PIPELINE_NAME"
      value = local.pipeline_name
    }

    environment_variable {
      name  = "ENVIRONMENTS"
      value = join(",", [for e in local.environments : e.name])
    }

    environment_variable {
      name  = "LAYERS"
      value = join(",", var.layers)
    }

    environment_variable {
      name  = "BASE_LAYER"
      value = local.base_layer
    }

    environment_variable {
      name  = "ENABLE_PARALLEL"
      value = var.enable_parallel_layers ? "true" : "false"
    }

    environment_variable {
      name  = "WATERMARK_PREFIX"
      value = var.watermark_prefix
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${local.pipeline_name}-route"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${var.buildspec_prefix}/route.yml"
  }
}

# --- plan --------------------------------------------------------------------

resource "aws_codebuild_project" "plan" {
  name          = "${local.pipeline_name}-plan"
  description   = "Runs terraform plan for one layer in one environment and saves the plan for approval."
  service_role  = local.codebuild_role_arn
  build_timeout = var.build_timeout_minutes
  tags          = var.tags

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    type         = var.terraform_compute.environment_type
    compute_type = var.terraform_compute.compute_type
    image        = var.terraform_compute.image

    environment_variable {
      name  = "WORKLOAD"
      value = var.workload
    }

    environment_variable {
      name  = "TF_VERSION"
      value = var.terraform_version
    }

    environment_variable {
      name  = "PLAN_PREFIX"
      value = var.plan_prefix
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${local.pipeline_name}-plan"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${var.buildspec_prefix}/plan.yml"
  }
}

# --- apply -------------------------------------------------------------------

resource "aws_codebuild_project" "apply" {
  name          = "${local.pipeline_name}-apply"
  description   = "Applies one layer in one environment, then records the commit as that layer's watermark."
  service_role  = local.codebuild_role_arn
  build_timeout = var.build_timeout_minutes
  tags          = var.tags

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    type         = var.terraform_compute.environment_type
    compute_type = var.terraform_compute.compute_type
    image        = var.terraform_compute.image

    environment_variable {
      name  = "WORKLOAD"
      value = var.workload
    }

    environment_variable {
      name  = "TF_VERSION"
      value = var.terraform_version
    }

    environment_variable {
      name  = "PLAN_PREFIX"
      value = var.plan_prefix
    }

    environment_variable {
      name  = "WATERMARK_PREFIX"
      value = var.watermark_prefix
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${local.pipeline_name}-apply"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "${var.buildspec_prefix}/apply.yml"
  }
}
