# Changelog

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
