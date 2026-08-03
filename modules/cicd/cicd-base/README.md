# cicd-base

A Terraform module for establishing the IAM foundation for cross-account CI/CD in an AWS Control Tower and Account Factory for Terraform (AFT) environment. The module supports both sides of the deployment model:

- **Hub mode** creates optional GitHub Actions OIDC access in the central CI/CD account.
- **Spoke mode** creates deployment roles in workload accounts that trust the central CI/CD account.

In both modes, role and account information is published as AWS Systems Manager (SSM) parameters in the AFT management account through the `aws.aft-management` provider alias.

## Usage

The module is published through GitHub. The following example configures hub mode and creates a repository-scoped GitHub Actions OIDC role:

```hcl
module "cicd_base" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/cicd-base?ref=cicd-cicd-base-v1.0"

  # To pin to a specific version, set ref to the corresponding release tag,
  # for example: cicd-cicd-base-v1.1.

  providers = {
    aws                   = aws
    "aws.aft-management" = aws.aft-management
  }

  deployment_type = "hub"

  github_oidc_roles = {
    "github-infra-deployer" = {
      subject_filter = "repo:your-org/your-infra-repo:ref:refs/heads/main"
      policy_arns    = []
    }
  }

  tags = {
    Environment = "shared-services"
    ManagedBy   = "terraform"
  }
}
```

For a workload account, use the same module source with `deployment_type = "spoke"` and provide the central CI/CD account ID:

```hcl
module "cicd_base_spoke" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/cicd-base?ref=cicd-cicd-base-v1.0"

  # To pin to a specific version, set ref to the corresponding release tag.

  providers = {
    aws                   = aws
    "aws.aft-management" = aws.aft-management
  }

  deployment_type = "spoke"
  cicd_account_id = "123456789012"

  custom_deployment_roles = {
    "app-deployer" = {
      policy_arns          = ["arn:aws:iam::aws:policy/AWSLambda_FullAccess"]
      inline_policy_json   = null
      permissions_boundary = null
    }
  }

  tags = {
    Environment = "workload"
    ManagedBy   = "terraform"
  }
}
```

The root configuration must define both provider configurations and pass the AFT management configuration through the `aws.aft-management` alias. The module's `aws` provider operates in the account being customized; the aliased provider operates in the AFT management account for SSM parameter publication.

### Hub mode behavior

Set `deployment_type` to `"hub"`. When `github_oidc_roles` is non-empty, the module creates the GitHub Actions OIDC provider and one IAM role per map entry. Each role is restricted by its `subject_filter` and can receive additional managed policies through `policy_arns`. Every OIDC role can assume a workload account role named `cicd-deployer`.

The hub account ID is published at `/org/core/accounts/cicd`. OIDC role ARNs are published at `/org/cicd/service-roles/github-oidc/<role-name>`.

### Spoke mode behavior

Set `deployment_type` to `"spoke"` and provide `cicd_account_id`. The module creates the fixed-name `cicd-deployer` role, trusts the central CI/CD account, and attaches the AWS managed `AdministratorAccess` policy. The role name and policy are architectural constants and are not configurable.

Additional roles can be defined with `custom_deployment_roles`. Each custom role can use AWS managed policies, an inline policy, and an optional permissions boundary. Deployment role ARNs are published at `/org/cicd/roles/<account-id>/deployer` and `/org/cicd/roles/<account-id>/custom/<role-name>`.

## Requirements

| Requirement | Version / configuration |
| --- | --- |
| Terraform | `>= 1.6.0` |
| AWS provider | `>= 6.23.0` |
| Provider alias | `aws.aft-management` must be configured for the AFT management account |

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | --- |
| `deployment_type` | Whether the module is deployed in the central CI/CD account (`hub`) or a workload account (`spoke`). | `string` | — | Yes |
| `github_oidc_roles` | Hub-mode map of GitHub OIDC IAM roles. Each entry requires a `subject_filter` and can include managed policy ARNs in `policy_arns`. | `map(object({ subject_filter = string, policy_arns = optional(list(string), []) }))` | `{}` | No |
| `cicd_account_id` | AWS account ID of the central CI/CD account. Spoke deployment roles trust this account. | `string` | `""` | No |
| `custom_deployment_roles` | Spoke-mode map of additional deployment roles. Each entry contains managed `policy_arns` and may include `inline_policy_json` and `permissions_boundary`. | `map(object({ policy_arns = list(string), inline_policy_json = optional(string), permissions_boundary = optional(string) }))` | `{}` | No |
| `tags` | Tags to apply to all resources. | `map(string)` | — | Yes |

### Input details

- `deployment_type` accepts only `"hub"` or `"spoke"`.
- `github_oidc_roles` is used only in hub mode. Its `policy_arns` attribute defaults to an empty list for each role.
- `cicd_account_id` is used only in spoke mode and should be set to the account ID of the central CI/CD account.
- `custom_deployment_roles` is used only in spoke mode. The optional `inline_policy_json` and `permissions_boundary` attributes are `null` when omitted.
- `tags` is required and is applied to IAM, OIDC provider, and SSM resources created by the module.

## Outputs

| Name | Description |
| --- | --- |
| `github_oidc_role_arns` | Map of GitHub OIDC role names to ARNs. Populated in hub mode; empty in spoke mode. |
| `deployer_role_arn` | ARN of the default `cicd-deployer` role. Populated in spoke mode; `null` in hub mode. |
| `deployer_role_name` | Name of the default deployment role. Always `cicd-deployer`. |
| `custom_role_arns` | Map of custom deployment role names to ARNs. Populated in spoke mode; empty in hub mode. |

## Security considerations

GitHub OIDC roles should use the narrowest practical `subject_filter`, such as a specific repository and branch or environment. Avoid adding broad managed policies to OIDC roles unless required. In spoke mode, the default `cicd-deployer` role intentionally grants `AdministratorAccess`; use `custom_deployment_roles` when a workload requires a more restricted permission set.
