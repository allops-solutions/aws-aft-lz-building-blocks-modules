# Terraform State Bootstrap Module

This module creates a secure S3 bucket for Terraform remote state storage in the current AWS account. The bucket is configured with versioning, encryption, public access blocking, and a policy that enforces secure (HTTPS) transport.

## Usage

```hcl
module "terraform_state" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/cicd/terraform-state-bootstrap?ref=cicd-terraform-state-bootstrap-v1.0"

  bucket_name_prefix = "my-org-terraform-state"

  tags = {
    Environment = "production"
    Owner       = "platform-team"
  }
}

# To pin to a specific version, replace the ref parameter:
# ref=cicd-terraform-state-bootstrap-v1.0
```

The bucket name is automatically constructed as `{bucket_name_prefix}-{aws_account_id}`, ensuring uniqueness across AWS accounts.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0 |
| aws | >= 6.23.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `bucket_name_prefix` | Prefix for the Terraform state bucket name. The current AWS account ID is appended automatically. | `string` | `"terraform-state"` | no |
| `tags` | Tags to apply to the Terraform state bucket resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `bucket_name` | Name of the Terraform state S3 bucket. |
| `bucket_arn` | ARN of the Terraform state S3 bucket. |

## Features

- **Versioning**: State versions are retained for recovery and auditing
- **Encryption**: AES256 server-side encryption at rest
- **Access Control**: Public access is blocked at all levels
- **Transport Security**: Bucket policy denies non-HTTPS requests
- **Ownership**: BucketOwnerEnforced object ownership for access consistency
- **Lifecycle Protection**: `prevent_destroy` protects the bucket from accidental deletion
- **Account Isolation**: Account ID automatically appended to bucket name for multi-account deployments
