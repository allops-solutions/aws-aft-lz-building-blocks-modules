# AFT Landing Zone Pipeline Module

A Terraform module for creating a self-managing AWS CodePipeline that orchestrates infrastructure provisioning for Control Tower, AWS Account Factory for Terraform (AFT), and organizational units. The pipeline runs in the AFT management account and assumes a cross-account role in the Control Tower management account to execute Terraform.

## Features

- **Flexible pipeline modes**: Choose between manual approval workflow or fully automated combined plan+apply
- **GitHub integration**: Uses AWS CodeConnections to connect to your landing zone repository
- **Cross-account execution**: Securely assumes roles in the Control Tower management account
- **Artifact management**: S3 bucket with versioning, lifecycle policies, and public access blocking
- **Execution tracking**: CloudWatch log groups for plan and apply operations
- **Configurable triggers**: Automatic pushes to main branch or manual execution
- **CodePipeline V2**: Modern pipeline implementation with SUPERSEDED execution mode

## Usage

### Basic Example

```hcl
module "landing_zone_pipeline" {
  source = "./modules/aft/landing-zone-pipeline"

  ct_home_region              = "eu-central-1"
  ct_management_account_id    = "123456789012"
  aft_management_account_id   = "210987654321"
  github_username             = "myorg"
  customer_name               = "acme-corp"

  enable_pipeline_trigger  = true
  enable_manual_approval   = true

  tags = {
    Environment = "production"
    Owner       = "infrastructure-team"
  }

  providers = {
    aws                = aws.aft-management
    aws.org-management = aws.ct-management
  }
}
```

### Manual Trigger Mode

```hcl
module "landing_zone_pipeline" {
  source = "./modules/aft/landing-zone-pipeline"

  ct_home_region              = "eu-central-1"
  ct_management_account_id    = "123456789012"
  aft_management_account_id   = "210987654321"
  github_username             = "myorg"
  customer_name               = "acme-corp"

  enable_pipeline_trigger  = false
  enable_manual_approval   = false

  providers = {
    aws                = aws.aft-management
    aws.org-management = aws.ct-management
  }
}
```

### Custom Terraform State Configuration

```hcl
module "landing_zone_pipeline" {
  source = "./modules/aft/landing-zone-pipeline"

  ct_home_region              = "eu-central-1"
  ct_management_account_id    = "123456789012"
  aft_management_account_id   = "210987654321"
  github_username             = "myorg"
  customer_name               = "acme-corp"

  tf_state_bucket = "my-custom-state-bucket"
  tf_state_key    = "infrastructure/terraform.tfstate"

  providers = {
    aws                = aws.aft-management
    aws.org-management = aws.ct-management
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 6.0.0 |

## Providers

This module requires two AWS provider configurations:

- **aws**: Primary provider for the AFT management account (where pipeline resources are created)
- **aws.org-management**: Secondary provider for the Control Tower/Organizations management account (where the cross-account execution role is created)

Configure both providers in your root module:

```hcl
provider "aws" {
  alias  = "aft-management"
  region = "eu-central-1"

  assume_role {
    role_arn = "arn:aws:iam::${var.aft_management_account_id}:role/TerraformExecutionRole"
  }
}

provider "aws" {
  alias  = "ct-management"
  region = "eu-central-1"

  assume_role {
    role_arn = "arn:aws:iam::${var.ct_management_account_id}:role/TerraformExecutionRole"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| ct_home_region | Control Tower home region — used to scope log/resource ARNs. | `string` | — | Yes |
| ct_management_account_id | The Control Tower / Organizations management account ID. CodeBuild assumes a role here to run Terraform. | `string` | — | Yes |
| aft_management_account_id | The AFT management account ID. Pipeline resources live here. | `string` | — | Yes |
| github_username | GitHub organization or username that owns the landing zone repo. | `string` | — | Yes |
| customer_name | Customer/project name prefix for the landing zone repo. | `string` | — | Yes |
| enable_pipeline_trigger | If true, the pipeline automatically triggers on pushes to the main branch. If false, the pipeline is created but must be triggered manually. | `bool` | `true` | No |
| enable_manual_approval | If true, the pipeline runs Source → Plan → Manual Approval → Apply. If false, it runs Source → Apply (combined plan+apply). | `bool` | `true` | No |
| tf_state_bucket | S3 bucket holding the Terraform state for this repo. Used to grant the cross-account role access to state. Leave empty to use the default naming convention. | `string` | `""` | No |
| tf_state_key | S3 key (path) of the Terraform state file inside tf_state_bucket. Leave empty to use the default naming convention. | `string` | `""` | No |
| ct_management_role_name | Name of the IAM role in the CT management account that CodeBuild assumes to run Terraform. | `string` | `"landing-zone-pipeline-execution"` | No |
| tags | Tags to apply to all resources. | `map(string)` | `{ "product" = "landing-zone", "created-by" = "AFT" }` | No |

## Outputs

This module does not define any outputs. The pipeline and related resources are created as-is, and consumers can reference the module's resources directly if needed (e.g., `module.landing_zone_pipeline.aws_codepipeline.this.name`).

## Pipeline Architecture

### With Manual Approval (Default)

```
Source (GitHub) → Plan (CodeBuild) → Manual Approval → Apply (CodeBuild)
```

1. **Source**: Retrieves code from the specified GitHub repository and main branch
2. **Plan**: Runs `terraform plan` in the Control Tower management account
3. **Approval**: Manual review stage with 30-minute timeout
4. **Apply**: Runs `terraform apply` using the saved plan artifact

### Without Manual Approval

```
Source (GitHub) → Apply (CodeBuild)
```

A single CodeBuild step runs `terraform init`, `terraform plan`, and `terraform apply` in sequence.

## Pipeline Execution

### Security Model

- Pipeline resources (CodePipeline, CodeBuild, S3, IAM roles) live in the AFT management account
- Terraform state and actual infrastructure resources live in the Control Tower management account
- CodeBuild assumes a cross-account role with AdministratorAccess in the Control Tower management account
- The cross-account role has a principal condition restricting it to the CodeBuild role ARN in the AFT account

### Artifact Store

- S3 bucket with versioning enabled
- Automatic expiration of artifacts after 14 days
- Noncurrent versions expire after 7 days
- Public access blocking enabled
- Used for storing source code zips, plan artifacts, and build outputs

### Logging

- CloudWatch log groups created for plan and apply operations (when manual approval is enabled)
- All log groups retain logs for 365 days
- Log group names follow the pattern: `/aws/codebuild/{solution_name}-{plan|apply}`

## Prerequisites

1. **CodeConnections Setup**: The module expects an existing AWS CodeConnections connection to GitHub, stored in SSM Parameter Store at `/aft/config/vcs/codeconnections-connection-arn`. This is typically created by AFT during initial setup.

2. **Repository Structure**: Your GitHub repository should be named `{customer_name}-aft-control-tower-account-setup` and contain Terraform configurations for your landing zone infrastructure.

3. **Buildspec Files**: Place buildspec files in the module's `assets/buildspecs/` directory:
   - `buildspec-plan.yml`: Instructions for running `terraform plan`
   - `buildspec-apply.yml`: Instructions for running `terraform apply` with a saved plan
   - `buildspec-combined.yml`: Instructions for running `terraform init`, `terraform plan`, and `terraform apply` in sequence

4. **Cross-Account Trust**: The Control Tower management account must allow the CodeBuild role in the AFT account to assume the cross-account execution role.

## Notes

- The pipeline uses Terraform version 1.15.0 by default. Adjust via the module's internal configuration if needed.
- CodeBuild uses ARM-based containers (amazonlinux2-aarch64-standard:4.0) for cost optimization
- Pipeline execution mode is set to SUPERSEDED, which terminates in-progress executions when a new one is triggered
- The solution name is hardcoded to `custom-aft-landing-zone`; customize by forking this module if different naming is needed

## Troubleshooting

**Pipeline fails to connect to GitHub**: Verify that the CodeConnections ARN in SSM Parameter Store at `/aft/config/vcs/codeconnections-connection-arn` is correct and that the connection is in an authorized state.

**CodeBuild assumes role fails**: Check that the cross-account execution role in the Control Tower management account has the correct trust policy and AdministratorAccess policy attachment.

**Terraform state access denied**: Ensure the CodeBuild role's policy grants S3 permissions for the state bucket and key specified in `tf_state_bucket` and `tf_state_key`.

**Plan artifact not found**: Verify that the `buildspec-plan.yml` file correctly outputs the plan artifact and that the Apply stage is configured to consume the `plan_output` artifact.
