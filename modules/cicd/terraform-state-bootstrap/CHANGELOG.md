# Changelog

## [v1.0] - 2026-07-24

### Added

- Initial release of the Terraform State Bootstrap module
- S3 bucket creation for Terraform remote state storage with automatic account ID appending
- Versioning enabled on state bucket for state history and recovery
- Server-side encryption (AES256) for state data at rest
- Public access block configuration to prevent accidental public exposure
- Bucket ownership controls enforcing BucketOwnerEnforced object ownership
- Bucket policy denying insecure (non-HTTPS) transport
- Lifecycle protection with `prevent_destroy` to safeguard state bucket from accidental deletion
- Configurable bucket name prefix with validation
- Support for custom tags on state bucket resources
- Outputs for bucket name and ARN for downstream resource dependencies


## [v1.0] - 2026-07-17

### Added
- Initial release of terraform-state-bootstrap module
- S3 bucket creation for Terraform remote state with account ID suffix
- S3 bucket versioning for state history and recovery
- Server-side encryption with AES256 (default S3 encryption)
- Public access block configuration to prevent accidental exposure
- Bucket ownership controls enforcing BucketOwnerEnforced
- Bucket policy to deny insecure (non-HTTPS) transport
- Lifecycle protection to prevent accidental bucket destruction
- Customizable bucket name prefix via `bucket_name_prefix` variable
- Support for custom tags via `tags` variable
- Output values: `bucket_name` and `bucket_arn` for downstream consumption
