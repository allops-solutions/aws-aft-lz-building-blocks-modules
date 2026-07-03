# CI/CD Base Module

A versatile Terraform module for setting up cross-account CI/CD infrastructure in AWS. This module handles both sides of the CI/CD deployment model: the central hub account (with GitHub OIDC provider and service roles) and workload spoke accounts (with cross-account deployment roles).

## Features

- **Hub mode:** GitHub Actions OIDC provider, scoped OIDC roles, CodeBuild and CodePipeline service roles
- **Spoke mode:** Default and custom deployment roles with configurable permissions
- **Role discovery:** Automatic publication of role ARNs to SSM Parameter Store in the AFT management account
- **Cross-account trust:** Secure role assumption across accounts with minimal configuration

## Usage

### Hub Mode (CICD Account)

Deploy this module in the central CI/CD account to set up GitHub Actions OIDC authentication and AWS service roles:

```hcl
module "cicd_hub" {
  source = "./modules/cicd/cicd-base"

  deployment_type = "hub"

  github_oidc_roles = {
    "github-infra-deployer" = {
      subject_filter = "repo:my-org/my-infra-repo:ref:refs/heads/main"
      policy_arns    = []
    }
    "github-app-deployer" = {
      subject_filter = "repo:my-org/my-app-repo:ref:refs/heads/main"
      policy_arns    = ["arn:aws:iam::aws:policy/CloudWatchFullAccess"]
    }
  }

  tags = {
    Environment = "shared"
    Module      = "cicd"
  }

  providers = {
    aws                = aws.cicd
    aws.aft-management = aws.management
  }
}

output "codebuild_role_arn" {
  value = module.cicd_hub.codebuild_role_arn
}

output "github_oidc_roles" {
  value = module.cicd_hub.github_oidc_role_arns
}
```

### Spoke Mode (Workload Accounts)

Deploy this module in each workload account to create deployment roles that trust the hub CI/CD account:

```hcl
module "cicd_spoke" {
  source = "./modules/cicd/cicd-base"

  deployment_type   = "spoke"
  cicd_account_id   = "123456789012"  # Your hub account ID

  custom_deployment_roles = {
    "lambda-deployer" = {
      policy_arns          = ["arn:aws:iam::aws:policy/AWSLambda_FullAccess"]
      inline_policy_json   = null
      permissions_boundary = null
    }
    "ec2-deployer" = {
      policy_arns = [
        "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
        "arn:aws:iam::aws:policy/IAMReadOnlyAccess"
      ]
      inline_policy_json   = null
      permissions_boundary = "arn:aws:iam::aws:policy/PowerUserAccess"
    }
  }

  tags = {
    Environment = "workload"
    Module      = "cicd"
  }

  providers = {
    aws                = aws.workload
    aws.aft-management = aws.management
  }
}

output "deployer_role_arn" {
  value = module.cicd_spoke.deployer_role_arn
}

output "custom_roles" {
  value = module.cicd_spoke.custom_role_arns
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 5.0 |

## Providers

This module requires two provider configurations:

- `aws` (primary): The account where this module is deployed
- `aws.aft-management`: The AFT management account where SSM parameters will be published

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `deployment_type` | Whether this module is deployed in the central CICD account ('hub') or a workload account ('spoke'). Must be 'hub' or 'spoke'. | `string` | N/A | yes |
| `github_oidc_roles` | Map of GitHub OIDC roles to create (hub mode only). Each role is scoped to specific repositories via subject_filter and granted sts:AssumeRole on workload deployment roles. Keys are role names. See example below. | `map(object({subject_filter = string, policy_arns = optional(list(string), [])}))` | `{}` | no |
| `cicd_account_id` | AWS account ID of the central CICD account (spoke mode only). The deployment roles trust this account. | `string` | `""` | no |
| `custom_deployment_roles` | Additional deployment roles with restricted permissions (spoke mode only). Keys are role names. See example below. | `map(object({policy_arns = list(string), inline_policy_json = optional(string), permissions_boundary = optional(string)}))` | `{}` | no |
| `tags` | Tags to apply to all resources. Passed in from the root module. | `map(string)` | N/A | yes |

### Variable Examples

#### `github_oidc_roles` (hub mode)

```hcl
github_oidc_roles = {
  "github-infra-deployer" = {
    subject_filter = "repo:your-org/your-infra-repo:ref:refs/heads/main"
    policy_arns    = []
  }
  "github-app-deployer" = {
    subject_filter = "repo:your-org/your-app-repo:*"
    policy_arns    = ["arn:aws:iam::aws:policy/CloudWatchFullAccess"]
  }
}
```

#### `custom_deployment_roles` (spoke mode)

```hcl
custom_deployment_roles = {
  "app-deployer" = {
    policy_arns          = ["arn:aws:iam::aws:policy/AWSLambda_FullAccess"]
    inline_policy_json   = null
    permissions_boundary = null
  }
  "restricted-deployer" = {
    policy_arns = ["arn:aws:iam::aws:policy/AmazonRDSReadOnlyAccess"]
    inline_policy_json = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = "s3:ListBucket"
          Resource = "arn:aws:s3:::my-bucket"
        }
      ]
    })
    permissions_boundary = "arn:aws:iam::aws:policy/PowerUserAccess"
  }
}
```

## Outputs

| Name | Description |
|------|-------------|
| `codebuild_role_arn` | ARN of the CodeBuild service role (hub mode only). Returns null in spoke mode. |
| `codepipeline_role_arn` | ARN of the CodePipeline service role (hub mode only). Returns null in spoke mode. |
| `github_oidc_role_arns` | Map of GitHub OIDC role names to their ARNs (hub mode only). Empty map in spoke mode. |
| `deployer_role_arn` | ARN of the default deployment role (spoke mode only). Returns null in hub mode. The role name is always `cicd-deployer` with AdministratorAccess policy. |
| `deployer_role_name` | Name of the default deployment role. Always returns `cicd-deployer` — not configurable. Available in both hub and spoke modes. |
| `custom_role_arns` | Map of custom deployment role names to their ARNs (spoke mode only). Empty map in hub mode. |

## Architecture

### Hub Mode

When deployed in the central CI/CD account with `deployment_type = "hub"`:

1. **GitHub OIDC Provider:** Establishes federated trust with GitHub Actions
2. **GitHub OIDC Roles:** Created per configured role with repository-specific subject filters
3. **GitHub Role Permissions:** All OIDC roles can assume `cicd-deployer` role in spoke accounts
4. **CodeBuild Service Role:** Trusts the CodeBuild service, can assume deployment roles in spoke accounts
5. **CodePipeline Service Role:** Trusts the CodePipeline service, can invoke CodeBuild, manage artifacts, and use CodeCommit/CodeStar connections

All role ARNs are published to SSM Parameter Store in the AFT management account at:
- `/org/cicd/service-roles/codebuild`
- `/org/cicd/service-roles/codepipeline`
- `/org/cicd/service-roles/github-oidc/{role_name}`

### Spoke Mode

When deployed in workload accounts with `deployment_type = "spoke"`:

1. **Default Deployer Role:** Named `cicd-deployer`, has AdministratorAccess, trusts the hub CI/CD account
2. **Custom Roles:** Optional additional roles with scoped permissions, optional permissions boundaries
3. **Trust Relationship:** All roles trust the root principal of the configured `cicd_account_id`

All role ARNs are published to SSM Parameter Store in the AFT management account at:
- `/org/cicd/roles/{account_id}/deployer`
- `/org/cicd/roles/{account_id}/custom/{role_name}`

## Notes

- The **deployer role name** (`cicd-deployer`) and default **policy** (`AdministratorAccess`) are architectural constants and not configurable
- GitHub OIDC **subject filters** should match your repository structure and branch protection rules. Examples:
  - Single branch: `repo:your-org/repo:ref:refs/heads/main`
  - All branches: `repo:your-org/repo:ref:refs/heads/*`
  - Workflows only: `repo:your-org/repo:ref:refs/heads/main:workflow_ref:*`
- The module requires provider aliases for SSM parameter publishing to work. Configure both `aws` and `aws.aft-management` providers in your calling module
- Custom roles support both managed policies (via `policy_arns`) and inline policies (via `inline_policy_json`)
- Permissions boundaries are optional and should reference valid AWS managed or customer managed policy ARNs
