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


