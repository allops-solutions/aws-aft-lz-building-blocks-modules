# Changelog
## [v1.2] - Unreleased
### Added
- `gitlab` (gitlab.com) support via a CodeConnections connection.
- New required provider alias `aws.aft-management`.
### Changed
- `vcs_provider`, `github_enterprise_url` and `gitlab_selfmanaged_url` default to `null`. When null, they are read from the AFT management account SSM parameters `/aft/config/vcs/provider`, `/aft/config/vcs/github-enterprise-url` and `/aft/config/vcs/gitlab-selfmanaged-url`. AFT's `"null"` placeholder is treated as unset, and trailing slashes are removed.
- GitHub Enterprise and GitLab self-managed hosts fail at plan with a clear error when no valid `https://<host>` URL is found.
- CodeBuild and CodePipeline roles allow `UseConnection`, `GetConnection` and `GetConnectionToken` under both `codestar-connections` and `codeconnections` prefixes.

## [v1.1] - 2026-11-26
### Added
- GitLab self-managed support (`vcs_provider = "gitlabselfmanaged"`). Creates a CodeConnections host and connection in the account the pipeline is deployed to. The connection must be authorized once in the console.
- `gitlab_selfmanaged_url` variable for the GitLab endpoint, for example `https://gitlab.example.com`.
