# Terraform State Bootstrap Module

This module creates a secure, production-ready S3 bucket for Terraform remote state in your AWS account. The bucket is automatically appended with the current account ID to ensure uniqueness across accounts and is configured with encryption, versioning, and security best practices.

## Usage

```hcl
module "terraform_state" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/terraform-state-bootstrap?ref=cicd-terraform-state-bootstrap-v1.0"

  bucket_name_prefix = "my-org-terraform-state"
  
  tags = {
    Environment = "shared"
    Purpose     = "terraform-state"
  }
}

# To pin to a specific version:
# source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/terraform-state-bootstrap?ref=cicd-terraform-state-bootstrap-v1.0"
```

The resulting S3 bucket name will be: `my-org-terraform-state-<account-id>`

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| bucket_name_prefix | Prefix for the Terraform state bucket name. The current AWS account ID is appended automatically. | `string` | `"terraform-state"` | no |
| tags | Tags to apply to the Terraform state bucket resources. | `map(string)` | `{}` | no |

### Validation

The `bucket_name_prefix` must:
- Start and end with a lowercase letter or digit
- Contain only lowercase letters, digits, dots, or hyphens
- Be 50 characters or fewer (to allow room for the appended account ID in the final bucket name)

## Outputs

| Name | Description |
|------|-------------|
| bucket_name | Name of the Terraform state S3 bucket. |
| bucket_arn | ARN of the Terraform state S3 bucket. |

## Features

- **S3 Bucket Versioning**: Enabled for state history and recovery
- **Server-Side Encryption**: AES256 encryption enabled by default
- **Public Access Blocking**: All public access is blocked
- **Bucket Ownership Controls**: Enforces BucketOwnerEnforced ownership model
- **Secure Transport Policy**: Denies any requests over non-HTTPS connections
- **Lifecycle Protection**: Prevents accidental bucket destruction with `prevent_destroy`
- **Account Isolation**: Bucket name includes account ID for multi-account deployments

## Examples

### Basic Usage

```hcl
module "terraform_state" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/terraform-state-bootstrap?ref=cicd-terraform-state-bootstrap-v1.0"
}
```

### With Custom Prefix and Tags

```hcl
module "terraform_state" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/terraform-state-bootstrap?ref=cicd-terraform-state-bootstrap-v1.0"

  bucket_name_prefix = "acme-terraform-state"
  
  tags = {
    Environment = "prod"
    Team        = "infrastructure"
    CostCenter  = "engineering"
  }
}

output "state_bucket" {
  value = module.terraform_state.bucket_name
}

output "state_bucket_arn" {
  value = module.terraform_state.bucket_arn
}
```
