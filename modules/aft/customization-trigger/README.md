# aft/customization-trigger

Automated pipeline that triggers AFT account and global customizations whenever changes are pushed to the corresponding GitHub repositories.

This module deploys a CodePipeline V2 in the AFT management account that listens for pushes to `main` on both the `global-customizations` and `account-customizations` repos and invokes the `aft-invoke-customizations` Step Function with `{"include": [{"type": "all"}]}`.

The module is **additive to AFT** — it does not modify any existing AFT resources and can be safely added or removed independently.

## Usage

```hcl
module "customization_trigger" {
  source = "./modules/aft/customization-trigger"

  ct_home_region            = "eu-central-1"
  aft_management_account_id = "123456789012"
  github_username           = "my-org"
  customer_name             = "acme"

  tags = {
    product    = "aft"
    created-by = "AFT"
    environment = "management"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 6.0.0 |

## Prerequisites

- The AFT module must be applied first so the SSM parameter `/aft/config/vcs/codeconnections-connection-arn` exists.
- The CodeConnections connection must be in `AVAILABLE` status.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `ct_home_region` | Control Tower home region. | `string` | — | yes |
| `aft_management_account_id` | The AWS account ID of the AFT management account where the Step Function lives. | `string` | — | yes |
| `github_username` | GitHub organization or username that owns the AFT repos. | `string` | — | yes |
| `customer_name` | Customer/project name prefix for AFT repo names. | `string` | — | yes |
| `tags` | Tags to apply to all resources. | `map(string)` | `{ "product" = "aft", "created-by" = "AFT" }` | no |

## Outputs

This module does not define any outputs.

## Resources Created

| Resource | Name | Purpose |
|----------|------|---------|
| `aws_codepipeline` | `custom-aft-customization-trigger` | V2 pipeline with git push triggers |
| `aws_codebuild_project` | `custom-aft-customization-trigger` | Invokes the Step Function via AWS CLI |
| `aws_s3_bucket` | `custom-aft-customization-trigger-*` | Pipeline artifact storage (1-day expiry) |
| `aws_iam_role` | `custom-aft-customization-trigger-pipeline` | Pipeline execution role |
| `aws_iam_role` | `custom-aft-customization-trigger-codebuild` | CodeBuild execution role |

## How It Works

1. A push to `main` on either the `<customer_name>-aft-global-customizations` or `<customer_name>-aft-account-customizations` repository triggers the pipeline via CodePipeline V2 git triggers.
2. The Source stage checks out both repositories.
3. The Invoke-Customizations stage runs a CodeBuild Lambda container that calls `aws stepfunctions start-execution` on the `aft-invoke-customizations` state machine.
4. AFT then applies all account and global customizations as normal.
