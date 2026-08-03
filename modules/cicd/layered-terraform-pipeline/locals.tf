# =============================================================================
# layered-terraform-pipeline -- derived model
#
# The pipeline is generated from a flat, ordered list of stage objects. Because
# CodePipeline has no cross-stage DAG, branching is expressed as a linear chain
# of mutually exclusive stages, each carrying a before_entry condition with a
# SKIP result. A skipped stage costs roughly zero seconds, so a chain of skips
# behaves like a branch.
#
# Two routing variables are exported by the route action, both with static
# names so that the buildspec can live in the repository as a plain file:
#
#   PLAN   ",dev/network,dev/databases,prod/services,"   what to run, per env
#   MODES  ",dev/sequential,prod/parallel,"              how to run it, per env
#
# Conditions use the CONTAINS operator against those strings. The delimiting
# commas make the matches unambiguous, so an environment called "dev" never
# matches an entry belonging to "dev-eu". Commas rather than semicolons because
# the values pass through a shell when the buildspec exports them.
# =============================================================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  region     = data.aws_region.current.region
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  pipeline_name = "${var.workload}-infrastructure"

  # Shared by the main and rollback pipelines' identical source stages.
  # OutputArtifactFormat = CODEBUILD_CLONE_REF is required: the default zip
  # artifact contains no .git directory, which would make change detection
  # impossible. Push triggering comes from the trigger block in pipeline.tf,
  # never from polling, so both pipelines keep DetectChanges false.
  source_config = var.source_provider == "github" ? {
    ConnectionArn        = var.connection_arn
    FullRepositoryId     = var.repository_id
    BranchName           = var.branch
    OutputArtifactFormat = "CODEBUILD_CLONE_REF"
    DetectChanges        = "false"
    } : {
    RepositoryName       = var.repository_id
    BranchName           = var.branch
    OutputArtifactFormat = "CODEBUILD_CLONE_REF"
    PollForSourceChanges = "false"
  }

  # The base layer sits at the bottom of the dependency chain. Any change to it
  # can shift the values its consumers read, whether or not its outputs file was
  # touched, so applying it always forces a sequential run.
  base_layer       = var.layers[0]
  dependent_layers = slice(var.layers, 1, length(var.layers))

  environments = concat(
    [{
      name         = var.dev_environment.name
      account_id   = var.dev_environment.account_id
      region       = coalesce(var.dev_environment.region, local.region)
      direct_apply = true
    }],
    [for e in var.intermediate_environments : {
      name         = e.name
      account_id   = e.account_id
      region       = coalesce(e.region, local.region)
      direct_apply = true
    }],
    [{
      name         = var.prod_environment.name
      account_id   = var.prod_environment.account_id
      region       = coalesce(var.prod_environment.region, local.region)
      direct_apply = false
    }],
  )

  env_layer_pairs = { for pair in flatten([
    for e in local.environments : [
      for l in var.layers : { key = "${e.name}/${l}", env = e, layer = l }
    ]
  ]) : pair.key => pair }

  # Only the non-direct-apply environment gets the plan -> approve -> apply
  # cycle, so the plan and approve actions are built over its pairs alone.
  approval_env_layer_pairs = { for key, pair in local.env_layer_pairs : key => pair if !pair.env.direct_apply }

  deployer_role_arns = [
    for e in local.environments :
    "arn:${local.partition}:iam::${e.account_id}:role/${var.deployer_role_name}"
  ]

  # ---------------------------------------------------------------------------
  # action environment variables
  # ---------------------------------------------------------------------------

  execution_env = [
    { name = "EXECUTION_ID", value = "#{codepipeline.PipelineExecutionId}", type = "PLAINTEXT" },
    { name = "COMMIT_ID", value = "#{SourceVariables.CommitId}", type = "PLAINTEXT" },
  ]

  env_target_env = { for e in local.environments : e.name => [
    { name = "ENV", value = e.name, type = "PLAINTEXT" },
    { name = "TARGET_REGION", value = e.region, type = "PLAINTEXT" },
    { name = "DEPLOYER_ROLE_ARN", value = "arn:${local.partition}:iam::${e.account_id}:role/${var.deployer_role_name}", type = "PLAINTEXT" },
    { name = "STATE_BUCKET", value = "${var.state_bucket_prefix}-${e.account_id}", type = "PLAINTEXT" },
  ] }

  # Base EnvironmentVariables payload for every plan/apply action, main and
  # rollback alike. The actions concat their own extras (ROUTE_PLAN, saved-plan
  # marker, TARGET_COMMIT) onto this, so a change here lands in both pipelines.
  layer_action_env = { for key, pair in local.env_layer_pairs : key => concat(
    local.execution_env,
    local.env_target_env[pair.env.name],
    [{ name = "LAYER", value = pair.layer, type = "PLAINTEXT" }],
  ) }

  # ---------------------------------------------------------------------------
  # skip conditions
  # ---------------------------------------------------------------------------

  # "does this environment have anything to do at all" -- gates the
  # inter-environment promotion approval so a no-op push never asks a
  # human to approve nothing.
  check_env_any = { for e in local.environments : e.name => {
    name     = "env-has-work"
    variable = "#{Route.PLAN}"
    value    = ",${e.name}/"
    operator = "CONTAINS"
  } }

  check_layer = { for key, pair in local.env_layer_pairs : key => {
    name     = "layer-changed"
    variable = "#{Route.PLAN}"
    value    = ",${pair.env.name}/${pair.layer},"
    operator = "CONTAINS"
  } }

  check_sequential = { for e in local.environments : e.name => {
    name     = "mode-sequential"
    variable = "#{Route.MODES}"
    value    = ",${e.name}/sequential,"
    operator = "CONTAINS"
  } }

  check_parallel = { for e in local.environments : e.name => {
    name     = "mode-parallel"
    variable = "#{Route.MODES}"
    value    = ",${e.name}/parallel,"
    operator = "CONTAINS"
  } }

  # ---------------------------------------------------------------------------
  # actions
  # ---------------------------------------------------------------------------

  # An action namespace makes a CodeBuild project's exported variables
  # referenceable as #{Name.VARIABLE} by other actions, so a namespace must be
  # unique within the pipeline and alphanumeric only ([A-Za-z0-9]). Only the
  # plan action exports a variable a downstream action consumes -- the approval
  # CustomData shows the rendered plan summary -- so only it carries one.
  # title() plus stripping non-alphanumerics maps "production/network" to
  # "PlanProductionNetwork".
  plan_namespace = { for key, pair in local.approval_env_layer_pairs : key =>
    "Plan${replace(title("${pair.env.name}-${pair.layer}"), "/[^A-Za-z0-9]/", "")}"
  }

  plan_actions = { for key, pair in local.approval_env_layer_pairs : key => {
    name      = "plan-${pair.layer}"
    namespace = local.plan_namespace[key]
    category  = "Build"
    provider  = "CodeBuild"
    run_order = 1
    configuration = {
      ProjectName = aws_codebuild_project.plan.name
      EnvironmentVariables = jsonencode(concat(
        local.layer_action_env[key],
        [
          { name = "ROUTE_PLAN", value = "#{Route.PLAN}", type = "PLAINTEXT" },
        ],
      ))
    }
  } }

  apply_actions = { for key, pair in local.env_layer_pairs : key => {
    name      = "apply-${pair.layer}"
    namespace = null
    category  = "Build"
    provider  = "CodeBuild"
    run_order = 1
    configuration = {
      ProjectName = aws_codebuild_project.apply.name
      EnvironmentVariables = jsonencode(concat(
        local.layer_action_env[key],
        [
          # The parallel stage applies every dependent layer, but only some of
          # them may be in this run. The buildspec re-checks and no-ops.
          { name = "APPLY_SAVED_PLAN", value = pair.env.direct_apply ? "false" : "true", type = "PLAINTEXT" },
          { name = "ROUTE_PLAN", value = "#{Route.PLAN}", type = "PLAINTEXT" },
        ],
      ))
    }
  } }

  approval_base = var.approval_sns_topic_arn == null ? {} : { NotificationArn = var.approval_sns_topic_arn }

  approve_plan_actions = { for key, pair in local.approval_env_layer_pairs : key => {
    name      = "approve"
    namespace = null
    category  = "Approval"
    provider  = "Manual"
    run_order = 1
    # The approve stage shares its plan stage's skip condition (check_layer),
    # so the two stages run or skip in lockstep: whenever this approval runs,
    # the plan action ran in the same execution and exported PLAN_SUMMARY.
    configuration = merge(local.approval_base, {
      CustomData = "Approve plan for ${pair.env.name}/${pair.layer} at commit #{SourceVariables.CommitId}?\n#{${local.plan_namespace[key]}.PLAN_SUMMARY}"
    })
  } }

  promote_approval_actions = { for e in local.environments : e.name => {
    name      = "approve"
    namespace = null
    category  = "Approval"
    provider  = "Manual"
    run_order = 1
    configuration = merge(local.approval_base, {
      CustomData = "Promote to ${e.name} at commit #{SourceVariables.CommitId}?"
    })
  } }

  # ---------------------------------------------------------------------------
  # stages
  #
  # For direct-apply environments (all except production/single):
  #   base layer -> [parallel dependent layers] -> sequential dependent layers
  #
  # For the last environment (production):
  #   For each layer: plan -> approve -> apply
  #   Layers run sequentially in dependency order.
  # ---------------------------------------------------------------------------

  stages = flatten([
    for idx, e in local.environments : concat(
      # Environment's own stages
      e.direct_apply ? concat(
        # Base layer applies first
        [{
          name    = "${e.name}-${local.base_layer}"
          checks  = [local.check_layer["${e.name}/${local.base_layer}"]]
          actions = [local.apply_actions["${e.name}/${local.base_layer}"]]
        }],
        # Optional parallel stage for dependent layers
        var.enable_parallel_layers ? [
          {
            name    = "${e.name}-parallel"
            checks  = [local.check_parallel[e.name]]
            actions = [for l in local.dependent_layers : local.apply_actions["${e.name}/${l}"]]
          },
        ] : [],
        # Sequential dependent layers
        [for l in local.dependent_layers : {
          name = "${e.name}-${l}"
          checks = [
            local.check_sequential[e.name],
            local.check_layer["${e.name}/${l}"],
          ]
          actions = [local.apply_actions["${e.name}/${l}"]]
        }]
        ) : flatten([
          # For the last environment (production): sequential plan -> approve -> apply per layer.
          # The approve stage exists only when manual approvals are enabled; otherwise the
          # pipeline goes straight from plan to the saved-plan apply.
          for l in var.layers : concat(
            [
              {
                name    = "${e.name}-plan-${l}"
                checks  = [local.check_layer["${e.name}/${l}"]]
                actions = [local.plan_actions["${e.name}/${l}"]]
              },
            ],
            var.enable_manual_approvals ? [
              {
                name    = "${e.name}-approve-${l}"
                checks  = [local.check_layer["${e.name}/${l}"]]
                actions = [local.approve_plan_actions["${e.name}/${l}"]]
              },
            ] : [],
            [
              {
                name    = "${e.name}-apply-${l}"
                checks  = [local.check_layer["${e.name}/${l}"]]
                actions = [local.apply_actions["${e.name}/${l}"]]
              },
            ],
          )
      ]),
      # Inter-environment promotion approval before the next environment. Present
      # only when manual approvals are enabled; the check_env_any condition is what
      # stops a no-op push from asking a human to approve nothing.
      var.enable_manual_approvals && idx < length(local.environments) - 1 ? [
        {
          name    = "approve-${local.environments[idx + 1].name}"
          checks  = [local.check_env_any[local.environments[idx + 1].name]]
          actions = [local.promote_approval_actions[local.environments[idx + 1].name]]
        }
      ] : []
    )
  ])

  # 2 fixed stages (source, route) plus the generated chain. CodePipeline allows
  # 50 stages; this is the number that variable validation on
  # intermediate_environments is protecting.
  stage_count = 2 + length(local.stages)
}
