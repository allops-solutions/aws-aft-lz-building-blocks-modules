# Changelog

## [v2.0] - 2026-07-01

### Added

- **Manual approval workflow**: New `enable_manual_approval` variable (default: `true`) that introduces a Plan → Approval → Apply pipeline flow. When enabled, a dedicated CodeBuild plan project runs `terraform plan`, exports the plan artifact, and a manual approval gate is required before apply.
- **Separate buildspec files**: Added `buildspec-plan.yml` (plan-only with artifact export), `buildspec-apply.yml` (apply-only from plan artifact), and `buildspec-combined.yml` (plan+apply in a single stage) to support both approval and non-approval workflows.
- **AFT account lifecycle event integration**: New Lambda function (`aft-new-account-event-forwarder`) that subscribes to the AFT SNS notification topic and forwards `CreateManagedAccount`/`UpdateManagedAccount` events to the pipeline's custom EventBridge bus.
- **Control Tower event forwarding**: Cross-account EventBridge rule in the CT management account that captures Control Tower lifecycle events and forwards them to the pipeline event bus.
- **Custom EventBridge bus**: Dedicated event bus (`<solution_name>-event-bus`) with cross-account permissions for receiving account lifecycle events.
- **`account_lifecycle_events_source` variable**: Choose between `AFT`, `CT`, or `None` to control how account lifecycle events trigger the pipeline.
- **`terraform_version` variable**: Pin the Terraform version installed in CodeBuild (default: `1.15.0`).
- **CodePipeline V2 with git triggers**: Explicit `trigger` block for GitHub/GitHub Enterprise VCS providers using `CodeStarSourceConnection` push events.
- **GitHub Enterprise Server support**: CodeConnections host resource with optional VPC configuration for GitHub Enterprise Server endpoints.
- **VPC configuration support**: Optional VPC networking for CodeBuild projects and CodeConnections hosts via `enable_vpc_config` and `vpc_config` variables.
- **IAM Identity Center policy**: Dedicated inline policy on the CodeBuild role granting permissions to manage SSO permission sets and account assignments.
- **CodeConnections permission**: Added `codestar-connections:UseConnection` to both CodeBuild and CodePipeline role policies.
- **S3 buckets with security hardening**: Pipeline artifact bucket and Terraform state backend bucket with KMS encryption, versioning, and public access blocks.
- **Provider lock file** (`.terraform.lock.hcl`): Pinned provider versions — `hashicorp/aws` v5.100.0, `hashicorp/archive` v2.8.0, `hashicorp/local` v2.9.0.

### Changed

- **Default VCS provider** changed to `github` (previously not explicitly set in v1.0 defaults).
- **Default Terraform version** updated to `1.15.0`.
- **CodeBuild image** uses ARM architecture (`aws/codebuild/amazonlinux2-aarch64-standard:4.0` with `ARM_CONTAINER` type).
- **Pipeline source action** uses `CODEBUILD_CLONE_REF` output format for GitHub/GitHub Enterprise (enables full git clone in CodeBuild).

### Removed

- **v1.0 release notes file** (`releases/v1.0.md`) removed from the module source tree.
