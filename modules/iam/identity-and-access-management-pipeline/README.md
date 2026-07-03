# Identity and Access Management Pipeline

This Terraform module provisions a fully automated CI/CD pipeline for managing IAM Identity Center (AWS SSO) permission sets and account assignments. It deploys AWS CodePipeline V2 with CodeBuild stages that run Terraform plan and apply, with optional manual approval gates. The pipeline can be automatically triggered by account lifecycle events from AWS Control Tower or Account Factory for Terraform (AFT).

## Architecture

The module creates:

- **CodePipeline V2** with Source → (Plan → Approval →) Apply stages
- **CodeBuild projects** running Terraform on ARM (Amazon Linux 2 aarch64)
- **S3 buckets** for pipeline artifacts and Terraform state backend (KMS-encrypted, versioned)
- **EventBridge** custom event bus for account lifecycle event integration
- **Lambda function** (AFT mode) to forward AFT SNS notifications to EventBridge
- **IAM roles** with least-privilege policies for all pipeline components
- **CodeConnections** for GitHub or GitHub Enterprise Server source integration

## Usage

### Basic — GitHub with manual approval (default)

```hcl
module "iam_pipeline" {
  source = "path/to/modules/iam/identity-and-access-management-pipeline"

  solution_name   = "aws-identity-mgmt"
  repository_name = "my-org/aws-permission-sets"
  branch_name     = "main"
  vcs_provider    = "github"

  enable_manual_approval          = true
  account_lifecycle_events_source = "None"
  terraform_version               = "1.15.0"

  tags = {
    Environment = "management"
    ManagedBy   = "terraform"
  }

  providers = {
    aws                      = aws
    aws.event-source-account = aws
  }
}
```

### With Control Tower event triggers

```hcl
module "iam_pipeline" {
  source = "path/to/modules/iam/identity-and-access-management-pipeline"

  solution_name                   = "aws-identity-mgmt"
  repository_name                 = "my-org/aws-permission-sets"
  branch_name                     = "main"
  vcs_provider                    = "github"
  account_lifecycle_events_source = "CT"

  providers = {
    aws                      = aws
    aws.event-source-account = aws.org-management
  }
}
```

### With AFT event triggers

```hcl
module "iam_pipeline" {
  source = "path/to/modules/iam/identity-and-access-management-pipeline"

  solution_name                   = "aws-identity-mgmt"
  repository_name                 = "my-org/aws-permission-sets"
  branch_name                     = "main"
  vcs_provider                    = "github"
  account_lifecycle_events_source = "AFT"

  providers = {
    aws                      = aws
    aws.event-source-account = aws.aft-management
  }
}
```

### With VPC configuration

```hcl
module "iam_pipeline" {
  source = "path/to/modules/iam/identity-and-access-management-pipeline"

  solution_name    = "aws-identity-mgmt"
  repository_name  = "my-org/aws-permission-sets"
  vcs_provider     = "githubenterprise"
  github_enterprise_url = "https://github.example.com"
  enable_vpc_config = true

  vpc_config = {
    vpc_id          = "vpc-0123456789abcdef0"
    subnets         = ["subnet-aaa", "subnet-bbb"]
    security_groups = ["sg-xxx"]
  }

  account_lifecycle_events_source = "None"

  providers = {
    aws                      = aws
    aws.event-source-account = aws
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.5.0 |
| AWS Provider (`hashicorp/aws`) | ~> 5.0 |

## Providers

| Name | Purpose |
|------|---------|
| `aws` | Primary provider — deploys pipeline resources |
| `aws.event-source-account` | Provider alias for the account that emits lifecycle events (CT management account, AFT management account, or default `aws` when `None`) |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `solution_name` | Solution name. Used for naming pipeline infrastructure resources (CodePipeline, CodeBuild, IAM roles, artifact bucket). Does NOT affect the Terraform state backend bucket. | `string` | `"aws-identity-mgmt"` | no |
| `repository_name` | VCS repository name. For external VCS, provide the full repository path (e.g. `GitHubOrganization/repository-name`). | `string` | `"aws-ps-pipeline"` | no |
| `branch_name` | Repository main branch name. | `string` | `"main"` | no |
| `vcs_provider` | Customer VCS provider. Valid values: `codecommit`, `github`, `githubenterprise`. | `string` | `"github"` | no |
| `github_enterprise_url` | GitHub Enterprise Server URL. Required only when `vcs_provider = "githubenterprise"`. | `string` | `"null"` | no |
| `enable_vpc_config` | Enable VPC configuration for CodeBuild projects and CodeConnections Host. | `bool` | `false` | no |
| `vpc_config` | VPC configuration for CodeBuild and CodeConnections. Only used when `enable_vpc_config = true`. | `object({ vpc_id = string, subnets = list(string), security_groups = list(string) })` | `{ vpc_id = "", subnets = [], security_groups = [] }` | no |
| `account_lifecycle_events_source` | Source of account lifecycle events to trigger the pipeline: `AFT`, `CT`, or `None`. | `string` | `"None"` | no |
| `terraform_version` | Terraform version to install in the CodeBuild pipeline. | `string` | `"1.15.0"` | no |
| `enable_manual_approval` | Enable a manual approval step between plan and apply stages in the pipeline. | `bool` | `true` | no |
| `tags` | Tags to apply to all supported resources. | `map(string)` | `{}` | no |

## Outputs

This module does not currently export outputs. Key resource attributes (pipeline ARN, bucket names, role ARNs) can be accessed by referencing the module's resources directly if needed.

## Notes

- **CodeConnections handshake**: When using GitHub or GitHub Enterprise, the CodeConnections connection is created in `PENDING` status. You must complete the handshake in the AWS Console before the pipeline can pull source code.
- **Terraform state bucket naming**: The backend bucket uses a fixed naming convention (`aws-identity-mgmt-tf-<account_id>-<region>`) regardless of the `solution_name` variable.
- **ARM architecture**: CodeBuild projects use ARM-based compute (`BUILD_GENERAL1_SMALL` with `amazonlinux2-aarch64-standard:4.0`).
- **Pipeline type**: Uses CodePipeline V2 which supports git-based triggers natively for GitHub/GitHub Enterprise sources.
