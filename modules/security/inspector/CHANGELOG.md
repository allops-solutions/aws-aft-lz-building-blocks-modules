# Changelog

## [v1.0] - 2026-07-24

### Added

- Initial release of the security/inspector module
- Amazon Inspector organization-wide enablement via AWS Organizations policies
- Support for multiple scan types: EC2, ECR, Lambda standard, Lambda code, and code repository scanning
- Multi-region support with primary, secondary, and additional regions
- Organizational unit (OU) path resolution (up to 3 levels deep) for flexible targeting
- Account-level exclusion capability to override OU-level enablement policies
- Delegated administrator account registration and activation
- ECR continuous re-scanning window configuration with configurable retention durations
- Automatic region deduplication and order-independent region lists
- Outputs for delegated admin account ID, managed regions, enablement policy ID, and association targets


                  + "CloudFormation.3",
                  + "CloudFormation.4",
                  + "CloudTrail.2",
                  + "GuardDuty.10",
                  + "GuardDuty.11",
                  + "GuardDuty.12",
                  + "GuardDuty.13",
                  + "GuardDuty.5",
                  + "GuardDuty.6",
                  + "GuardDuty.7",
                  + "GuardDuty.8",
                  + "GuardDuty.9",
                  + "IAM.19",
                  + "IAM.28",
                  + "Inspector.2",
                  + "Inspector.3",
                  + "Inspector.4",
                  + "SSM.6",