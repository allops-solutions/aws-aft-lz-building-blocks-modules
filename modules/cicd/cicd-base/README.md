# CICD Base Module

The `cicd/cicd-base` Terraform module provides the IAM and role-discovery foundation for cross-account CI/CD on AWS. It supports both sides of the architecture:

- **Hub mode**: deployed in the central CI/CD account to create a GitHub Actions OIDC provider and repository-scoped IAM roles.
- **Spoke mode**: deployed in workload accounts to create deployment roles trusted by the central CI/CD account.

In either mode, role and account information is published to AWS Systems Manager Parameter Store in the AFT management account. Pipeline-specific CodeBuild and CodePipeline service roles remain the responsibility of the pipeline module that uses this foundation.

## Usage

The module requires both the default AWS provider and an `aws.aft-management` provider alias. The aliased provider is used to publish discovery parameters in the AFT management account.

The following example configures the central CI/CD account in hub mode:

```hcl
provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "aft-management"
  region = var.aft_management_region

  # Configure assume_role here when the AFT management account is accessed
  # through a role.
}

module "cicd_base" {
  # Pin to the released module version. To pin to another specific version,
  # replace the ref value with the desired release tag, for example:
  # ref=cicd-cicd-base-v1.1
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/cicd-base?ref=cicd-cicd-base-v1.0"

  providers = {
    aws                  = aws
    aws.aft-management   = aws.aft-management
  }

  deployment_type = "hub"

  github_oidc_roles = {
    "github-infra-deployer" = {
      subject_filter = "repo:your-org/your-infra-repo:ref:refs/heads/main"
      policy_arns    = []
    }
  }

  tags = {
    ManagedBy = "Terraform"
    Component = "cicd"
  }
}
```

For a workload account, use the same module source with `deployment_type = "spoke"` and provide the central CI/CD account ID:

```hcl
module "cicd_base" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/cicd-base?ref=cicd-cicd-base-v1.0"

  providers = {
    aws                = aws
    aws.aft-management = aws.aft-management
  }

  deployment_type = "spoke"
  cicd_account_id = var.cicd_account_id

  custom_deployment_roles = {
    "app-deployer" = {
      policy_arns          = ["arn:aws:iam::aws:policy/AWSLambda_FullAccess"]
      inline_policy_json   = null
      permissions_boundary = null
    }
  }

  tags = {
    ManagedBy = "Terraform"
    Component = "cicd"
  }
}
```

### Hub mode

Hub mode creates the GitHub OIDC provider only when `github_oidc_roles` is non-empty. Each configured role:

- Trusts GitHub Actions through the GitHub OIDC provider.
- Restricts access using the configured `subject_filter`.
- Can assume `cicd-deployer` roles in workload accounts.
- Can receive additional managed policies through `policy_arns`.

The hub account ID is published at `/org/core/accounts/cicd`. Each GitHub OIDC role ARN is published at `/org/cicd/service-roles/github-oidc/<role-name>`.

### Spoke mode

Spoke mode creates the fixed-name `cicd-deployer` role and attaches the AWS-managed `AdministratorAccess` policy. The role trusts the root principal of `cicd_account_id`.

Additional roles can be declared in `custom_deployment_roles`. These roles use the same trust relationship and may have managed policies, an inline JSON policy, and a permissions boundary.

The default deployer ARN is published at `/org/cicd/roles/<account-id>/deployer`. Custom role ARNs are published at `/org/cicd/roles/<account-id>/custom/<role-name>` in the AFT management account.

## Requirements

| Name | Version |
| --- | --- |
| Terraform | `>= 1.6.0` |
| AWS provider | `>= 6.23.0` |

The module declares the `aws.aft-management` provider configuration alias. The caller must configure and pass that alias in the module's `providers` map.

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | --- |
| `deployment_type` | Whether the module is deployed in the central CI/CD account (`hub`) or a workload account (`spoke`). | `string` | — | Yes |
| `github_oidc_roles` | Hub-mode map of GitHub OIDC roles. Each object contains a repository `subject_filter` and optional additional managed `policy_arns`. | `map(object({ subject_filter = string, policy_arns = optional(list(string), []) }))` | `{}` | No |
| `cicd_account_id` | AWS account ID of the central CI/CD account. Spoke deployment roles trust this account. | `string` | `""` | No |
| `custom_deployment_roles` | Spoke-mode map of additional deployment roles. Each object contains `policy_arns`, optional `inline_policy_json`, and optional `permissions_boundary`. | `map(object({ policy_arns = list(string), inline_policy_json = optional(string), permissions_boundary = optional(string) }))` | `{}` | No |
| `tags` | Tags applied to all resources created by the module. | `map(string)` | — | Yes |

`deployment_type` accepts only `hub` or `spoke`. The default spoke deployment role name (`cicd-deployer`) and its `AdministratorAccess` policy are architectural constants and are not configurable.

## Outputs

| Name | Description |
| --- | --- |
| `github_oidc_role_arns` | Map of GitHub OIDC role names to their ARNs. Populated in hub mode when OIDC roles are configured. |
| `deployer_role_arn` | ARN of the default `cicd-deployer` role in spoke mode; `null` in hub mode. |
| `deployer_role_name` | Name of the default deployment role, always `cicd-deployer`. |
| `custom_role_arns` | Map of custom deployment role names to their ARNs. Populated in spoke mode. |

## Versioning

This release is consumed with the following module reference:

```text
github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/cicd-base?ref=cicd-cicd-base-v1.0
```

The tag follows the pattern `<module-name-with-dashes>-<version>`.
