# Landing Zone Pipeline

A Terraform module that deploys a self-managing AWS CodePipeline (V2) in the AFT management account to automate Terraform plan and apply for the landing zone bootstrap repository (Control Tower, Organizations, AFT, and OUs).

The pipeline reuses the existing AFT CodeConnections (read from SSM) and assumes a cross-account IAM role in the CT management account to run Terraform where the state and resources live.

## Pipeline Modes

| Mode | Flow | Controlled by |
|------|------|---------------|
| **Approval** (default) | Source → Plan → Manual Approval → Apply | `enable_manual_approval = true` |
| **Auto-apply** | Source → Apply (combined plan + apply) | `enable_manual_approval = false` |

## Usage

```hcl
module "landing_zone_pipeline" {
  source = "path/to/modules/aft/landing-zone-pipeline"

  providers = {
    aws                = aws               # AFT management account
    aws.org-management = aws.org-management # CT management account
  }

  ct_home_region            = "eu-central-1"
  ct_management_account_id  = "111111111111"
  aft_management_account_id = "222222222222"
  github_username           = "my-org"
  customer_name             = "acme"

  enable_pipeline_trigger = true
  enable_manual_approval  = true

  tags = {
    product    = "landing-zone"
    created-by = "AFT"
  }
}
```

## Requirements

| Requirement | Version |
|---|---|
| Terraform | >= 1.5.0 |
| AWS Provider | >= 6.0.0 |

## Providers

This module requires **two** AWS provider configurations:

| Provider | Target Account |
|---|---|
| `aws` (default) | AFT management account — pipeline, CodeBuild, S3, and logs |
| `aws.org-management` | CT management account — cross-account execution role |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `ct_home_region` | Control Tower home region — used to scope log/resource ARNs. | `string` | — | yes |
| `ct_management_account_id` | The Control Tower / Organizations management account ID. CodeBuild assumes a role here to run Terraform. | `string` | — | yes |
| `aft_management_account_id` | The AFT management account ID. Pipeline resources live here. | `string` | — | yes |
| `github_username` | GitHub organization or username that owns the landing zone repo. | `string` | — | yes |
| `customer_name` | Customer/project name prefix for the landing zone repo. | `string` | — | yes |
| `enable_pipeline_trigger` | If true, the pipeline automatically triggers on pushes to the main branch. If false, the pipeline must be triggered manually. | `bool` | `true` | no |
| `enable_manual_approval` | If true, the pipeline runs Source → Plan → Manual Approval → Apply. If false, it runs Source → Apply (combined plan+apply). | `bool` | `true` | no |
| `tf_state_bucket` | S3 bucket holding the Terraform state for this repo. Defaults to `terraform-state-terraform-account-factory-<ct_management_account_id>`. | `string` | `""` | no |
| `tf_state_key` | S3 key (path) of the Terraform state file inside `tf_state_bucket`. Defaults to `custom-aft-landing-zone/terraform.tfstate`. | `string` | `""` | no |
| `ct_management_role_name` | Name of the IAM role in the CT management account that CodeBuild assumes to run Terraform. | `string` | `"landing-zone-pipeline-execution"` | no |
| `tags` | Tags to apply to all resources. | `map(string)` | `{ product = "landing-zone", created-by = "AFT" }` | no |

## Outputs

This module does not currently export any outputs.

## Resources Created

- **S3 bucket** — Pipeline artifact storage with versioning, lifecycle policy (14-day expiry), and public access blocked.
- **CloudWatch Log Groups** — Separate log groups for plan and apply builds (365-day retention).
- **IAM Role (CodeBuild)** — Permissions to write logs, access artifacts, and assume the cross-account role.
- **IAM Role (CodePipeline)** — Permissions to use the CodeConnection, start builds, and access artifacts.
- **CodeBuild Projects** — Plan project (conditional) and apply project using ARM-based `amazonlinux2-aarch64-standard:4.0` images.
- **CodePipeline V2** — Orchestrates source, plan, approval, and apply stages with optional Git push trigger.
- **IAM Role (CT Management)** — Cross-account execution role with `AdministratorAccess`, scoped trust to the CodeBuild role in the AFT account.

## Prerequisites

1. The SSM parameter `/aft/config/vcs/codeconnections-connection-arn` must exist in the AFT management account (created by the AFT module).
2. Both AWS providers must be configured before calling the module.
3. The module creates an IAM role with `AdministratorAccess` in the CT management account — review your organization's security policies before deploying.

## Terraform Version

Builds use **Terraform 1.15.0** (pinned in the buildspec install phase).
