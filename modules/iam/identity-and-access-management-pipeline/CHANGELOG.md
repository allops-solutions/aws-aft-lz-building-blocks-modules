# Changelog

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.0] - 2026-07-03

### Added

- **Initial release of the Identity and Access Management Pipeline module**
- CodePipeline infrastructure for automated Terraform plan/apply workflows
- CodeBuild projects for Terraform plan and apply stages with support for manual approval workflows
- Support for multiple version control systems:
  - AWS CodeCommit
  - GitHub
  - GitHub Enterprise Server
- EventBridge integration to trigger pipelines from account lifecycle events:
  - AWS Control Tower (CT) account provisioning events
  - AWS Account Factory for Terraform (AFT) account provisioning events
  - Manual trigger via dedicated event bus
- IAM roles and policies for:
  - CodePipeline orchestration
  - CodeBuild execution with Identity Center permissions
  - EventBridge event routing
  - Lambda event forwarding (AFT mode)
  - Control Tower event capture and forwarding
- S3 buckets for:
  - CodePipeline artifacts with encryption and versioning
  - Terraform state backend with encryption and versioning
- Lambda function for forwarding AFT new account notifications to the pipeline event bus
- CloudWatch log groups for CodeBuild plan and apply stages with 365-day retention
- VPC configuration support for CodeBuild projects and GitHub Enterprise connections
- Support for Terraform version customization via environment variables
- Configurable branch targeting and repository integration
- Security features:
  - S3 bucket public access blocking
  - KMS encryption for S3 buckets
  - S3 versioning for state and artifacts
  - Least-privilege IAM policies
  - Checkov security compliance annotations
