# Changelog

## [v2.0] - 2026-08-03

### Added
- **Finding notifications pipeline**: EventBridge rule to filter Security Hub findings by severity and workflow status, triggering a Lambda formatter that renders findings into human-readable email notifications delivered via SNS.
- **SNS notification topic**: Encrypted topic (`securityhub-finding-notifications`) with automatic email subscription to the delegated administrator account's root email.
- **Lambda formatter function**: Processes Security Hub findings (including those from GuardDuty, Inspector, Macie, and IAM Access Analyzer) and formats them for email delivery. Supports per-product routing and notification suppression policies for control findings (notifies on first observation and monthly reminders only).
- **Notification severity filtering**: Configurable minimum severity threshold (LOW, MEDIUM, HIGH, or CRITICAL) applied at the EventBridge rule level; passing control findings are automatically filtered out as INFORMATIONAL.
- **Test events documentation**: Comprehensive guide (`TEST_EVENTS.md`) for testing the notification pipeline with real end-to-end scenarios, synthetic findings, and unit tests.
- **Deployment gate**: Internal resource to sequence this module after prerequisite modules (e.g., GuardDuty, Inspector).

### Changed
- **Module scope expanded**: Now manages the complete Security Hub CSPM configuration including finding notifications, not just standards and configuration policies.

### Fixed
- N/A

### Removed
- N/A

### Notes
- The notification pipeline is always deployed; recipients can opt out by unsubscribing from the SNS topic (matching Control Tower's aggregate topic model).
- Severity floor filtering is applied at the EventBridge rule level before the Lambda is invoked, optimizing cost and reducing unnecessary function executions.
- The Lambda suppression policy ensures control findings (ProductName = "Security Hub") are not over-delivered: first observation triggers a notification, old findings are suppressed, and monthly reminders are sent on the 1st of each month. Non-control products (GuardDuty, Inspector, etc.) are always delivered if they clear the severity floor.
