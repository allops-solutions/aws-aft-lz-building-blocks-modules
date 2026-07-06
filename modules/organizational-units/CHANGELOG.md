# Changelog

## [1.0.0] - 2026-07-06

### Added

- Initial release of the organizational-units module
- Child OU creation with support for nested hierarchy under root OUs
- Automatic discovery of Control Tower baseline definitions via `list-baselines` API
- Detection of currently-enabled baselines via `list-enabled-baselines` API
- AWSControlTowerBaseline enablement on all root and child OUs
- BackupBaseline enablement on OUs via `enable_backup` variable (optional)
- Dynamic parameter support for IdentityCenterEnabledBaselineArn when Identity Center is active
- Proper dependency chain: root baselines → child baselines → optional backup baselines
- Output exports for child OUs (id, arn, name) and discovered baseline IDs
- Python-based baseline discovery script embedded via `external` data source
