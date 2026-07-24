# Changelog

## [1.0.0] - 2026-07-24

### Added
- Initial release of the `organizational-units` module for managing AWS Organizations Organizational Units with Control Tower integration
- Support for hierarchical OU creation: root-level OUs and nested child OUs
- Automatic baseline discovery via `aws controltower list-baselines` and `aws controltower list-enabled-baselines`
- Automatic AWSControlTowerBaseline enablement on all root and child OUs
- Optional BackupBaseline enablement on all OUs via `enable_backup` variable
- Dynamic baseline parameter support for IdentityCenterEnabledBaselineArn when Identity Center is active
- Module outputs: `child_ous` (OU metadata) and `baseline_ids` (baseline name-to-ID mapping)
- Dependency management ensuring root baselines are applied before child OUs, and child baselines follow root baselines


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
