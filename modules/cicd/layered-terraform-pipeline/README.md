# Layered Terraform Pipeline Module

The `cicd/layered-terraform-pipeline` module creates a dependency-aware AWS CodePipeline V2 delivery system for Terraform infrastructure. It routes changes through an ordered list of layers and environments, runs direct applies in non-production environments, and provides production plan, optional manual approval, and apply stages for each layer.

The module also creates a separate manual-only rollback pipeline. A rollback checks out a user-selected commit and plans and applies every production layer in reverse dependency order. The main pipeline and rollback pipeline share the module's CodeBuild projects and artifact storage.

## Features

- Generates a layered pipeline from an ordered dependency list, such as `network`, `databases`, and `services`.
- Tracks the last-applied commit for each environment and layer in SSM Parameter Store so the router can skip unaffected work.
- Supports GitHub through AWS CodeConnections or AWS CodeCommit as the source provider.
- Supports direct applies for development and intermediate environments, optional parallel dependent-layer applies, and sequential production promotion.
- Supports optional manual approvals and SNS notifications.
- Creates only three CodeBuild projects—router, plan, and apply—regardless of the number of environments or layers.
- Creates dedicated CodePipeline and CodeBuild service roles scoped to this pipeline.
- Creates an encrypted, versioned artifact bucket when an existing bucket is not supplied.
- Provides a production rollback pipeline that runs against an explicitly selected commit.

## Usage

The example below creates a pipeline sourcing a GitHub repository through an AWS CodeConnections connection. The deployer role must already exist in each target account unless `create_deployment_roles` is enabled for a self-contained, same-account deployment.

```hcl
provider "aws" {
  region = var.region
}

module "layered_terraform_pipeline" {
  # Pin to the released module version. To pin to another specific version,
  # replace the ref value with the desired release tag, for example:
  # ref=cicd-layered-terraform-pipeline-v1.1
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/layered-terraform-pipeline?ref=cicd-layered-terraform-pipeline-v1.0"

  workload = "payments"

  # The first layer is the base layer and establishes dependency order.
  layers = ["network", "databases", "services"]

  dev_environment = {
    name       = "dev"
    account_id = var.dev_account_id
    region     = var.region
  }

  prod_environment = {
    name       = "prod"
    account_id = var.prod_account_id
    region     = var.region
  }

  source_provider = "github"
  connection_arn  = var.codeconnections_arn
  repository_id   = "example-org/payments-infrastructure"
  branch          = "main"

  enable_parallel_layers = true
  enable_manual_approvals = true

  tags = {
    ManagedBy = "Terraform"
    Component = "layered-terraform-pipeline"
  }
}
```

For AWS CodeCommit, set `source_provider = "codecommit"`, omit `connection_arn`, and set `repository_id` to the CodeCommit repository name. The module creates an EventBridge rule to start the main pipeline when the configured branch changes.

### Pipeline behavior

The main pipeline starts with source and routing stages. The router compares the source commit with SSM watermarks and exports the layers and environments that need work. Generated stages use CodePipeline variable checks to skip unaffected layers.

- The base layer is applied first in each direct-apply environment.
- Dependent layers can run in parallel when `enable_parallel_layers` is enabled and the route permits it.
- Sequential dependent-layer stages follow the configured layer order.
- The final environment, normally production, runs each layer through plan, optional manual approval, and apply stages.
- `enable_manual_approvals = false` removes promotion and production approval actions, but does not disable automatic source triggers.
- `execution_mode` is fixed to `QUEUED` so a newer source commit does not cancel an in-progress apply or run concurrent applies against the same Terraform state.

The main pipeline exposes a `FORCE_MODE` variable. Set it to `full-sequential` when starting an execution manually to run every layer in order and bypass change detection.

### Rollback

The module creates a rollback pipeline named `<workload>-rollback-production-infrastructure`. It is manual-only and has a required `TARGET_COMMIT` pipeline variable. Start it from the CodePipeline console, set `TARGET_COMMIT` to the commit to restore, review the generated plans, and approve the applies when manual approvals are enabled. The rollback processes layers in reverse dependency order and refuses to treat the current branch head as a rollback target.

## Requirements

| Name | Version |
| --- | --- |
| Terraform | `>= 1.6.0` |
| AWS provider | `>= 6.0` |

The caller must configure the AWS provider in the account and Region where the pipelines, service roles, SSM watermark parameters, and—when enabled—the artifact bucket and deployment roles are created. The target environment accounts must contain the deployer role named by `deployer_role_name` unless `create_deployment_roles = true` is used in a same-account configuration.

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | --- |
| `workload` | Workload name used in the pipeline name, state key prefix, and SSM watermark prefix. Must contain lowercase letters, digits, and dashes. | `string` | — | Yes |
| `layers` | Layers in dependency order. The first entry is the base layer; applying it forces a sequential run. Must contain at least two entries. | `list(string)` | `["network", "databases", "services"]` | No |
| `dev_environment` | First environment. Direct apply is used with no plan or approval. | `object({ name = optional(string, "dev"), account_id = string, region = optional(string) })` | — | Yes |
| `prod_environment` | Final environment. Each layer receives a sequential plan, optional approval, and apply cycle. | `object({ name = optional(string, "prod"), account_id = string, region = optional(string) })` | — | Yes |
| `intermediate_environments` | Environments inserted in order between development and production. Each uses direct apply. At most five may be configured. | `list(object({ name = string, account_id = string, region = optional(string) }))` | `[]` | No |
| `source_provider` | Source system. `github` uses a CodeConnections connection; `codecommit` uses an EventBridge rule for change detection. | `string` | `"github"` | No |
| `connection_arn` | AWS CodeConnections connection ARN. Required when `source_provider = "github"`. | `string` | `null` | No* |
| `repository_id` | Repository identifier: `org/repo` for GitHub or the repository name for CodeCommit. | `string` | — | Yes |
| `branch` | Source-of-truth branch that drives the main pipeline. | `string` | `"main"` | No |
| `deployer_role_name` | Role assumed in each target account. This is normally the `cicd-deployer` role created by `cicd-base` in spoke mode. | `string` | `"cicd-deployer"` | No |
| `create_deployment_roles` | Whether to create the deployer role in the current account instead of assuming it already exists in target accounts. Use for a self-contained same-account configuration. | `bool` | `false` | No |
| `deployment_role_policy_arns` | Policies attached to a deployer role when `create_deployment_roles = true`. | `list(string)` | `["arn:aws:iam::aws:policy/AdministratorAccess"]` | No |
| `state_bucket_prefix` | Prefix of the Terraform state bucket in each target account. The bucket name is `<prefix>-<account_id>`. | `string` | `"terraform-state"` | No |
| `plan_prefix` | Key prefix in each state bucket where approved Terraform plans are stored. | `string` | `"_plans"` | No |
| `watermark_prefix` | SSM Parameter Store prefix in the current account for the last-applied commit for each environment and layer. Must start with `/` and not end with `/`. | `string` | `"/pipeline"` | No |
| `enable_parallel_layers` | Whether direct-apply environments may apply dependent layers in parallel when the base layer is unchanged and no layer contract changed. Production remains sequential. | `bool` | `true` | No |
| `enable_manual_approvals` | Whether to include inter-environment promotion approvals and production per-layer approvals. Source triggers remain active when this is false; rollback remains manual-only. | `bool` | `true` | No |
| `terraform_version` | Terraform version installed and used by the plan and apply buildspecs. | `string` | `"1.15.3"` | No |
| `buildspec_prefix` | Directory in the source repository containing `route.yml`, `plan.yml`, and `apply.yml`. | `string` | `"buildspecs"` | No |
| `build_timeout_minutes` | Timeout for the plan and apply CodeBuild projects. | `number` | `60` | No |
| `approval_sns_topic_arn` | Optional SNS topic notified by manual approval actions. | `string` | `null` | No |
| `route_compute` | Compute settings for the routing project. The default uses ARM Lambda compute. | `object({ environment_type = optional(string, "ARM_LAMBDA_CONTAINER"), compute_type = optional(string, "BUILD_LAMBDA_1GB"), image = optional(string, "aws/codebuild/amazonlinux-aarch64-lambda-standard:python3.14") })` | `{}` | No |
| `terraform_compute` | Compute settings for plan and apply projects. Lambda compute is not permitted because Terraform can write outside `/tmp` and exceed Lambda's 15-minute limit. | `object({ environment_type = optional(string, "ARM_CONTAINER"), compute_type = optional(string, "BUILD_GENERAL1_SMALL"), image = optional(string, "aws/codebuild/amazonlinux2-aarch64-standard:4.0") })` | `{}` | No |
| `artifact_bucket_name` | Existing CodePipeline artifact bucket. Set to `null` to have the module create one. | `string` | `null` | No |
| `artifact_retention_days` | Number of days before artifacts expire when the module creates the artifact bucket. | `number` | `90` | No |
| `tags` | Tags applied to resources created by the module. | `map(string)` | `{}` | No |

`*` `connection_arn` is conditionally required when `source_provider` is `"github"`.

## Outputs

| Name | Description |
| --- | --- |
| `pipeline_name` | Name of the main CodePipeline pipeline. |
| `pipeline_arn` | ARN of the main CodePipeline pipeline. |
| `stage_names` | Generated stages in execution order, including `source` and `route`. Useful for confirming the topology before applying. |
| `codebuild_role_arn` | ARN of the CodeBuild service role created for this pipeline. |
| `codepipeline_role_arn` | ARN of the CodePipeline service role created for this pipeline. |
| `deployer_role_arns` | Map of environment names to the deployer role ARN assumed in each target account. |
| `artifact_bucket` | Name of the S3 bucket holding CodePipeline artifacts. |
| `watermark_parameter_prefix` | SSM prefix in the current account where each layer's last-applied commit is recorded. |
| `codebuild_projects` | Map containing the names of the `route`, `plan`, and `apply` CodeBuild projects. |
| `rollback_pipeline_name` | Name of the rollback CodePipeline pipeline. |
| `rollback_pipeline_arn` | ARN of the rollback CodePipeline pipeline. |

## Versioning

This release is consumed with the following module reference:

```text
github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/layered-terraform-pipeline?ref=cicd-layered-terraform-pipeline-v1.0
```

The tag follows the pattern `<module-name-with-dashes>-<version>`.
