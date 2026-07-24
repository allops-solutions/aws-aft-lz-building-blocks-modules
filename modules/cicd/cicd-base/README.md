# CI/CD Module

A versatile Terraform module for establishing cross-account CI/CD infrastructure on AWS. This module handles both the central CI/CD account (hub) and workload accounts (spokes), enabling secure, role-based deployment workflows with GitHub Actions OIDC, CodeBuild, CodePipeline, and custom deployment roles.

## Features

- **GitHub Actions OIDC**: Scoped IAM roles for GitHub workflows with fine-grained repository-level access control
- **Service Roles**: CodeBuild and CodePipeline roles in the hub with cross-account permissions
- **Custom Deployment Roles**: Spoke-mode support for multiple deployment roles with restricted permissions and inline policies
- **Cross-Account Discovery**: Automatic role ARN publication to SSM Parameter Store for dynamic discovery
- **Flexible Configuration**: Support for permissions boundaries, inline policies, and custom policy attachments

## Usage

### Hub Mode (CICD Account)

Deploy in your central CI/CD AWS account with GitHub OIDC:

```hcl
module "cicd_hub" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/cicd-base?ref=cicd-cicd-base-v1.0"

  deployment_type = "hub"

  github_oidc_roles = {
    "github-infra-deployer" = {
      subject_filter = "repo:my-org/my-infra-repo:ref:refs/heads/main"
      policy_arns    = []
    }
    "github-app-deployer" = {
      subject_filter = "repo:my-org/my-app-repo:*"
      policy_arns    = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    }
  }

  tags = {
    Environment = "shared"
    Module      = "cicd"
  }

  providers = {
    aws.aft-management = aws.aft-management
  }
}

# Pin to a specific version by modifying the ref:
# ref=cicd-cicd-base-v1.0.1
```

### Spoke Mode (Workload Account)

Deploy in workload accounts with cross-account trust to the hub:

```hcl
module "cicd_spoke" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/cicd-base?ref=cicd-cicd-base-v1.0"

  deployment_type  = "spoke"
  cicd_account_id  = "123456789012"  # Your CICD account ID

  custom_deployment_roles = {
    "app-deployer" = {
      policy_arns          = ["arn:aws:iam::aws:policy/AWSLambda_FullAccess"]
      inline_policy_json   = null
      permissions_boundary = null
    }
    "data-deployer" = {
      policy_arns = [
        "arn:aws:iam::aws:policy/AmazonS3FullAccess",
        "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
      ]
      inline_policy_json   = null
      permissions_boundary = "arn:aws:iam::aws:policy/PowerUserAccess"
    }
  }

  tags = {
    Environment = "production"
    Module      = "cicd"
  }

  providers = {
    aws.aft-management = aws.aft-management
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 6.23.0 |

## Providers

| Name | Version | Alias |
|------|---------|-------|
| aws | >= 6.23.0 | `aws` (primary), `aws.aft-management` (required) |

The module requires a provider alias `aws.aft-management` pointing to the AFT management account for SSM parameter storage. Configure it in your provider block:

```hcl
provider "aws" {
  alias  = "aft-management"
  region = var.aws_region
  assume_role {
    role_arn = "arn:aws:iam::MANAGEMENT_ACCOUNT_ID:role/OrganizationAccountAccessRole"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `deployment_type` | Whether this module is deployed in the central CICD account (`hub`) or a workload account (`spoke`). | `string` | N/A | yes |
| `github_oidc_roles` | Map of GitHub OIDC roles to create (hub mode only). Each role is scoped to specific repositories via `subject_filter` and granted `sts:AssumeRole` on workload deployment roles. | `map(object({ subject_filter = string, policy_arns = optional(list(string), []) }))` | `{}` | no |
| `cicd_account_id` | AWS account ID of the central CICD account (spoke mode only). The deployment roles trust this account. | `string` | `""` | no |
| `custom_deployment_roles` | Additional deployment roles with restricted permissions (spoke mode only). Supports policy ARNs, inline policies, and permissions boundaries. | `map(object({ policy_arns = list(string), inline_policy_json = optional(string), permissions_boundary = optional(string) }))` | `{}` | no |
| `tags` | Tags to apply to all resources. | `map(string)` | N/A | yes |

### Hub Mode (`deployment_type = "hub"`)

#### `github_oidc_roles`

Map of GitHub OIDC roles with the following attributes:

- **`subject_filter`** (required, string): GitHub Actions subject filter for OIDC token matching. Examples:
  - `repo:my-org/my-repo:ref:refs/heads/main` — Allow deployments from `main` branch only
  - `repo:my-org/my-repo:*` — Allow all workflows in the repository
  - `repo:my-org/my-repo:environment:production` — Allow deployments from the `production` environment

- **`policy_arns`** (optional, list of strings): Additional AWS IAM policy ARNs to attach to the role. Default: `[]`

In hub mode, all GitHub OIDC roles automatically receive `sts:AssumeRole` permissions on the `cicd-deployer` role in all accounts.

### Spoke Mode (`deployment_type = "spoke"`)

#### `cicd_account_id`

The AWS account ID of the central CICD account. Deployment roles in spoke accounts trust this account's root principal.

#### `custom_deployment_roles`

Map of custom deployment roles with the following attributes:

- **`policy_arns`** (required, list of strings): IAM policy ARNs to attach to the role.

- **`inline_policy_json`** (optional, string): An inline IAM policy JSON document. If provided, creates an inline policy on the role. Useful for complex, account-specific permissions. Default: `null`

- **`permissions_boundary`** (optional, string): ARN of a permissions boundary policy. Restricts the maximum permissions the role can assume. Default: `null`

In spoke mode, a default role named `cicd-deployer` with `AdministratorAccess` is always created. This is an architectural constant and cannot be customized.

## Outputs

| Name | Description |
|------|-------------|
| `codebuild_role_arn` | ARN of the CodeBuild service role (hub mode only). Returns `null` in spoke mode. |
| `codepipeline_role_arn` | ARN of the CodePipeline service role (hub mode only). Returns `null` in spoke mode. |
| `github_oidc_role_arns` | Map of GitHub OIDC role names to their ARNs (hub mode only). Empty map in spoke mode. |
| `deployer_role_arn` | ARN of the default deployment role (spoke mode only). Returns `null` in hub mode. |
| `deployer_role_name` | Name of the default deployment role. Always `"cicd-deployer"`. |
| `custom_role_arns` | Map of custom deployment role names to their ARNs (spoke mode only). Empty map in hub mode. |

## Architecture

### Hub Mode

In the central CICD account:

1. **GitHub OIDC Provider**: Federated identity provider for GitHub Actions
2. **GitHub OIDC Roles**: Scoped roles that trust the OIDC provider and can assume workload deployment roles
3. **CodeBuild Role**: Service role for CodeBuild with artifacts, logging, and workload assumption permissions
4. **CodePipeline Role**: Service role for CodePipeline with CodeBuild integration and multi-account permissions

All hub roles automatically get `sts:AssumeRole` permissions on the `cicd-deployer` role in all accounts (via the `arn:aws:iam::*:role/cicd-deployer` resource pattern).

### Spoke Mode

In workload accounts:

1. **Default Deployer Role**: Named `cicd-deployer` with AdministratorAccess, trusts the CICD account root
2. **Custom Roles**: Optional additional roles with restricted policies, permissions boundaries, and inline policies
3. **Cross-account Trust**: All roles trust the central CICD account, enabling the hub to assume them

## SSM Parameter Publication

Both modes publish role ARNs to the AFT management account's SSM Parameter Store for dynamic discovery.

### Hub Mode Parameters

- `/org/core/accounts/cicd` — CICD account ID
- `/org/cicd/service-roles/codebuild` — CodeBuild role ARN
- `/org/cicd/service-roles/codepipeline` — CodePipeline role ARN
- `/org/cicd/service-roles/github-oidc/{role-name}` — GitHub OIDC role ARN (per role)

### Spoke Mode Parameters

- `/org/cicd/roles/{account-id}/deployer` — Default deployer role ARN
- `/org/cicd/roles/{account-id}/custom/{role-name}` — Custom role ARN (per role)

## Examples

### Hub with Multiple GitHub OIDC Roles

```hcl
module "cicd" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/cicd-base?ref=cicd-cicd-base-v1.0"

  deployment_type = "hub"

  github_oidc_roles = {
    "github-terraform-deployer" = {
      subject_filter = "repo:my-org/infrastructure:ref:refs/heads/main"
      policy_arns    = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    }
    "github-app-ci" = {
      subject_filter = "repo:my-org/backend-service:*"
      policy_arns    = []
    }
  }

  tags = {
    Owner = "platform-engineering"
  }

  providers = {
    aws.aft-management = aws.aft-management
  }
}
```

### Spoke with Restricted Custom Role

```hcl
module "cicd" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/cicd-base?ref=cicd-cicd-base-v1.0"

  deployment_type  = "spoke"
  cicd_account_id  = "123456789012"

  custom_deployment_roles = {
    "lambda-deployer" = {
      policy_arns = [
        "arn:aws:iam::aws:policy/AWSLambda_FullAccess",
        "arn:aws:iam::aws:policy/AmazonAPIGatewayInvokeFullAccess"
      ]
      permissions_boundary = "arn:aws:iam::aws:policy/PowerUserAccess"
      inline_policy_json   = jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Effect   = "Allow"
          Action   = "iam:PassRole"
          Resource = "arn:aws:iam::ACCOUNT_ID:role/lambda-execution-role"
        }]
      })
    }
  }

  tags = {
    Environment = "production"
  }

  providers = {
    aws.aft-management = aws.aft-management
  }
}
```

## License

This module is part of the AWS AFT Landing Zone Building Blocks.
