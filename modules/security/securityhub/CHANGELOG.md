# Changelog

## [1.0.0] - 2026-07-03

### Added

- Initial release of the Security Hub module
- Support for AWS Security Hub organization configuration
- Finding aggregator resource for centralized account management
- Variables for configuring linking mode: `NO_REGIONS`, `ALL_REGIONS`, `SPECIFIED_REGIONS`, `ALL_REGIONS_EXCEPT_SPECIFIED`
- Auto-enable Security Hub for organization accounts via `auto_enable_accounts` variable
- Auto-enable Security Hub standards for organization accounts via `auto_enable_standards` variable
- Configuration type support for `CENTRAL` and `LOCAL` deployments
- Input validation for linking modes and configuration types
- Support for Terraform >= 1.5.0 and AWS provider >= 5.62
