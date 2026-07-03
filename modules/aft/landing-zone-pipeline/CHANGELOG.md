# Changelog

## [v2.0] — 2026-07-01

### Added

- **Buildspec files as external YAML assets** — Plan, apply, and combined buildspecs are now stored as real YAML files under `assets/buildspecs/` and loaded via `data "local_file"` resources (`buildspecs.tf`). This improves readability, linting, and editor support compared to inline HCL strings.
- **Dedicated `buildspecs.tf`** — New file that declares the three `local_file` data sources for buildspec-plan, buildspec-apply, and buildspec-combined.
- **`buildspec-plan.yml`** — Installs Terraform, assumes the cross-account role, runs `terraform init`, `terraform validate`, and `terraform plan`, then exports the full workspace as a pipeline artifact.
- **`buildspec-apply.yml`** — Installs Terraform, assumes the cross-account role, runs `terraform init`, and conditionally applies a saved plan file (branch-gated).
- **`buildspec-combined.yml`** — Single-stage buildspec that performs init, validate, plan, and conditional apply in one CodeBuild execution (used when manual approval is disabled).
- **Branch safety gate in apply steps** — Both the apply and combined buildspecs skip `terraform apply` when the detected Git branch does not match the configured `BRANCH_NAME`, preventing accidental applies from feature branches.
- **`terraform validate` in plan/combined buildspecs** — Adds an explicit validation step before planning to catch configuration errors early.

### Removed

- **Previous v1.0 release notes** — The `releases/v1.0.md` file has been removed from the module source tree (release documentation is now maintained externally).
