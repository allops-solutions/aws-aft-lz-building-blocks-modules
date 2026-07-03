# Changelog

## [v1.0] - 2026-07-03

### Added

- Initial release of the `aft/landing-zone-pipeline` module
- Self-managing CodePipeline for the Control Tower + AFT bootstrap repository
- AWS CodeConnections integration for GitHub source control
- Flexible pipeline modes:
  - **Manual approval mode** (default): Source → Plan → Manual Approval → Apply
  - **Combined mode**: Source → Apply (plan and apply in single CodeBuild run)
- CodeBuild projects for Terraform plan and apply operations
- S3 artifact store with versioning, lifecycle policies, and public access blocking
- CloudWatch log groups for CodeBuild execution tracking
- Cross-account IAM roles for secure Terraform execution in Control Tower management account
- Pipeline trigger configuration (automatic on main branch push or manual)
- Support for custom Terraform state bucket and key paths
- Comprehensive IAM policies for CodePipeline and CodeBuild services
- CodePipeline V2 with SUPERSEDED execution mode for optimal performance
- Configurable tags for all resources
