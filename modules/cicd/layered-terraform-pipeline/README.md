# layered-terraform-pipeline

A Terraform module that creates a change-aware AWS CodePipeline for layered Terraform deployments. It routes only the environments and layers affected by a commit, applies direct environments in dependency order, and promotes the final environment through saved Terraform plans with optional manual approvals.

The module also creates a separate, manual-only rollback pipeline for applying the production configuration from a specified Git commit.

## How it works

The pipeline creates three CodeBuild projects—route, plan, and apply—and passes the environment and layer context to each action. It does not create one CodeBuild project per environment or layer.

- **Route:** compares the source commit with each environment/layer watermark and exports the layers that need work and the required execution mode.
- **Direct environments:** apply the base layer first, then apply dependent layers in parallel when safe or sequentially when required.
- **Final environment:** runs `plan -> approve -> apply` for each layer in dependency order. Approvals can be removed with `enable_manual_approvals = false`.
- **Rollback:** runs every production layer in reverse dependency order at the commit supplied through the `TARGET_COMMIT` pipeline variable.
- **Watermarks:** successful applies record their commit in SSM Parameter Store in the CI/CD account, independently for each environment and layer.

The first layer in `layers` is the base layer. Any run involving the base layer is forced to execute sequentially. Changes to a layer's outputs contract and shared pipeline files also force safe sequential behavior.

## Usage

```hcl
module "layered_terraform_pipeline" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/layered-terraform-pipeline?ref=layered-terraform-pipeline-v1.0"
  # Pin to a different specific release by changing the ref, for example:
  # ref=layered-terraform-pipeline-v1.1

  workload      = "customer-platform"
  repository_id = "allops-solutions/customer-platform-infrastructure"
  branch        = "main"
  connection_arn = "arn:aws:codestar-connections:eu-central-1:123456789012:connection/00000000-0000-0000-0000-000000000000"

  dev_environment = {
    account_id = "111111111111"
    region     = "eu-central-1"
  }

  prod_environment = {
    account_id = "222222222222"
    region     = "eu-central-1"
  }

  # Optional environments are inserted between dev and prod.
  intermediate_environments = [
    {
      name       = "staging"
      account_id = "333333333333"
      region     = "eu-central-1"
    }
  ]

  # Set to false to remove all approval stages while retaining saved-plan
  # plan/apply behavior and source triggers.
  enable_manual_approvals = true
}
```

The example uses the GitHub source format and the `layered-terraform-pipeline-v1.0` release tag. Replace the example account IDs, connection ARN, repository, and workload with values for your environment.

For a CodeCommit source, set `source_provider = "codecommit"`, provide the CodeCommit repository name in `repository_id`, and omit `connection_arn`. The module creates an EventBridge rule for branch changes in that mode.

## Deployment modes

### Hub and spoke

Set `codepipeline_role_arn` and `codebuild_role_arn` to existing service roles, normally supplied by the CI/CD hub. Leave `create_deployment_roles = false`; the CodeBuild role assumes `deployer_role_name` in each target account.

### Self-contained account

Leave the service role ARNs null and set `create_deployment_roles = true`. The module creates the CodePipeline role, CodeBuild role, and deployer role in the current account. Every configured environment must use the current account because Terraform can create the deployer role only through the account where the provider is configured. The policies in `deployment_role_policy_arns` are attached to that role; the default is `AdministratorAccess`, so replace it with least-privilege policies where appropriate.

The target accounts must already contain the Terraform state buckets named `<state_bucket_prefix>-<account_id>`. The module creates a CodePipeline artifact bucket when `artifact_bucket_name` is not supplied.

## Rollback

The `${workload}-rollback-production-infrastructure` pipeline is manual-only and is never started by a source push.

1. Open the rollback pipeline in CodePipeline and choose **Release change**.
2. Set the `TARGET_COMMIT` pipeline variable to the commit to restore.
3. Review and approve each layer when manual approvals are enabled.
4. The pipeline applies `services`, then `databases`, then the base layer (for the default layer list, `network`).

An empty `TARGET_COMMIT` is rejected by the build scripts. The rollback pipeline checks out the requested commit in the build rather than relying on a source-action version override.

## Requirements

| Requirement | Version / details |
|---|---|
| Terraform | `>= 1.10.0` |
| AWS provider | `>= 6.0` |
| AWS services | CodePipeline V2, CodeBuild, S3, IAM, SSM Parameter Store, and either CodeConnections or CodeCommit/EventBridge, depending on `source_provider` |
| Repository contract | The source repository must provide the configured buildspec directory with `route.yml`, `plan.yml`, and `apply.yml`; the build scripts also expect the repository's Makefile and Terraform layer layout described by the pipeline contract |

The default route project uses ARM Lambda compute. Lambda compute is not available in every AWS Region; use the `route_compute` input to select ARM container compute when necessary. Terraform plan and apply projects use non-Lambda compute because Terraform can write outside `/tmp` and can exceed Lambda's 15-minute runtime limit.

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `workload` | Workload name used for pipeline, state-key, and watermark naming. Lowercase letters, digits, and dashes are required. | `string` | — | Yes |
| `layers` | Layers in dependency order. The first layer is the base layer and forces sequential execution when it runs. | `list(string)` | `["network", "databases", "services"]` | No |
| `dev_environment` | First environment. Direct apply is used without a plan or approval stage. Object fields: `name`, `account_id`, and optional `region`. | `object` | — | Yes |
| `prod_environment` | Final environment. Each layer is planned, optionally approved, and applied in dependency order. Object fields: `name`, `account_id`, and optional `region`. | `object` | — | Yes |
| `intermediate_environments` | Environments inserted between dev and prod. They use direct apply. At most five are supported. | `list(object)` | `[]` | No |
| `source_provider` | Source system: `github` uses CodeConnections; `codecommit` uses an EventBridge change-detection rule. | `string` | `"github"` | No |
| `connection_arn` | CodeConnections connection ARN. Required when `source_provider` is `github`. | `string` | `null` | No |
| `repository_id` | Repository identifier: `org/repo` for GitHub or the repository name for CodeCommit. | `string` | — | Yes |
| `branch` | Source branch that drives the main pipeline. | `string` | `"main"` | No |
| `codepipeline_role_arn` | Existing CodePipeline service-role ARN. Null causes the module to create the role. | `string` | `null` | No |
| `codebuild_role_arn` | Existing CodeBuild service-role ARN. Null causes the module to create the role. | `string` | `null` | No |
| `deployer_role_name` | Role name assumed in each target account. | `string` | `"cicd-deployer"` | No |
| `create_deployment_roles` | Create the deployer role in the current account instead of assuming roles that already exist in target accounts. | `bool` | `false` | No |
| `deployment_role_policy_arns` | Policy ARNs attached to the deployer role when `create_deployment_roles` is true. | `list(string)` | `["arn:aws:iam::aws:policy/AdministratorAccess"]` | No |
| `state_bucket_prefix` | Prefix for target-account Terraform state buckets, which are named `<prefix>-<account_id>`. | `string` | `"terraform-state"` | No |
| `plan_prefix` | Key prefix inside each state bucket for saved plans. | `string` | `"_plans"` | No |
| `watermark_prefix` | SSM prefix in the CI/CD account for per-environment, per-layer last-applied commits. Must start with `/` and not end with `/`. | `string` | `"/pipeline"` | No |
| `enable_parallel_layers` | Add a direct-environment stage that applies dependent layers in parallel when routing determines it is safe. Production remains sequential. | `bool` | `true` | No |
| `enable_manual_approvals` | Include inter-environment and per-layer approval actions. When false, pipelines run end-to-end without approval stages. | `bool` | `true` | No |
| `terraform_version` | Terraform version installed by the plan and apply buildspecs. | `string` | `"1.15.3"` | No |
| `buildspec_prefix` | Directory containing `route.yml`, `plan.yml`, and `apply.yml`. | `string` | `"buildspecs"` | No |
| `build_timeout_minutes` | Timeout for plan and apply CodeBuild projects. | `number` | `60` | No |
| `approval_sns_topic_arn` | Optional SNS topic notified by manual approval actions. | `string` | `null` | No |
| `route_compute` | Compute settings for the route project: `environment_type`, `compute_type`, and `image`. | `object` | `{}` | No |
| `terraform_compute` | Compute settings for plan and apply: `environment_type`, `compute_type`, and `image`. Lambda compute is rejected. | `object` | `{}` | No |
| `artifact_bucket_name` | Existing CodePipeline artifact bucket. Null causes the module to create one. | `string` | `null` | No |
| `artifact_retention_days` | Retention period for artifacts when the module creates the artifact bucket. | `number` | `90` | No |
| `tags` | Tags applied to resources created by the module. | `map(string)` | `{}` | No |

## Outputs

| Name | Description |
|---|---|
| `pipeline_name` | Name of the main CodePipeline pipeline. |
| `pipeline_arn` | ARN of the main CodePipeline pipeline. |
| `stage_names` | Generated stages in execution order, including `source` and `route`. |
| `codebuild_role_arn` | CodeBuild service role ARN in use, whether supplied or created by the module. |
| `codepipeline_role_arn` | CodePipeline service role ARN in use, whether supplied or created by the module. |
| `deployer_role_arns` | Map of environment name to the deployer role ARN assumed in that environment's account. |
| `artifact_bucket` | CodePipeline artifact bucket name. |
| `watermark_parameter_prefix` | SSM prefix where each layer's last-applied commit is stored. |
| `codebuild_projects` | Map containing the names of the `route`, `plan`, and `apply` CodeBuild projects. |
| `rollback_pipeline_name` | Name of the production rollback pipeline. |
| `rollback_pipeline_arn` | ARN of the production rollback pipeline. |

## Source-trigger behavior

For GitHub, the V2 CodePipeline trigger watches the configured branch and starts only for changes under the configured layer directories, `Makefile`, or the buildspec directory. Markdown files are excluded. For CodeCommit, the equivalent branch update is handled by EventBridge.

The source trigger is independent of `enable_manual_approvals`: disabling approvals does not disable automatic main-pipeline runs. The rollback pipeline has no source trigger and is always manual-only.

## License

See the repository license for licensing terms.
