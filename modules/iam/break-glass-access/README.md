# Break-Glass Access Module

Emergency access for AWS environments when IAM Identity Center and/or the external IdP are unavailable. This module provides a single, dormant, MFA-protected, console-only IAM user in the Control Tower management account that can switch-role into `AWSControlTowerExecution` across all Control Tower-managed accounts.

## Features

- **Single break-glass IAM user** with console-only access (no programmatic access keys)
- **MFA-enforced** assume-role capability to switch between accounts
- **Automated bookmarks page** listing all enrolled Control Tower accounts as switch-role links
- **Detective alerting** via SNS email on any break-glass user activity (sign-in, role assumption, write operations)
- **Automatic refresh** triggered by Control Tower account lifecycle events and periodic schedule
- **Minimal CloudTrail trail** created automatically when centralized logging is disabled
- **All resources in us-east-1** where global console events land

## Usage

```hcl
module "break_glass" {
  source = "./modules/iam/break-glass-access"

  ct_management_account_id = "123456789012"
  notification_email       = "aws-root@example.com"

  tags = {
    Environment = "core"
    Owner       = "platform-team"
  }
}
```

After deployment:

1. Retrieve initial password: `aws ssm get-parameter --name "/break-glass/initial-password" --with-decryption --query "Parameter.Value" --output text`
2. Sign in to the console with the break-glass user at the output URL
3. **Change the password on first login** (required)
4. Enroll in MFA immediately
5. Invoke the refresh Lambda to generate the bookmarks page: `aws lambda invoke --function-name break-glass-refresh /dev/null`

The break-glass user should be stored in a vault for emergency use only.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 6.0.0 |
| archive | >= 2.0.0 |
| random | >= 3.0.0 |

The AWS provider must be configured with the `aws.org-management` alias pointing to the Control Tower management account in the `us-east-1` region.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| ct_management_account_id | The Control Tower / Organizations management account ID. All break-glass resources are created here. | `string` | | yes |
| break_glass_user_name | Name of the single break-glass IAM user created in the management account. | `string` | `"break-glass-user"` | no |
| notification_email | Email address subscribed to the break-glass usage SNS topic. This is intentionally the same mailbox as the organization root user (e.g. aws-root@example.com) so that break-glass activity is visible to the same closely-held distribution list. The subscription must be confirmed once by clicking the link in the confirmation email. | `string` | | yes |
| target_role_name | The role the break-glass user switches into within each Control Tower-managed account. AWSControlTowerExecution exists in every CT-enrolled account, grants AdministratorAccess, and trusts the management account. Do not change unless your landing zone uses a different execution role. | `string` | `"AWSControlTowerExecution"` | no |
| refresh_schedule_expression | EventBridge schedule for the periodic bookmarks refresh (covers account suspensions, for which there is no event trigger). Defaults to weekly. | `string` | `"rate(7 days)"` | no |
| bookmarks_object_key | S3 object key for the rendered break-glass bookmarks HTML page. | `string` | `"breakglass.html"` | no |
| enable_centralized_logging | Whether Control Tower centralized logging (organization CloudTrail trail) is enabled. When true, the CT org trail provides EventBridge delivery — no extra trail is created. When false, this module creates a minimal multi-region CloudTrail trail in the management account to ensure EventBridge can receive sign-in events for alerting. | `bool` | `false` | no |
| tags | Tags to apply to all resources. Passed in from the root module — do not set defaults here. | `map(string)` | | yes |

## Outputs

| Name | Description |
|------|-------------|
| break_glass_user_name | Name of the break-glass IAM user in the management account. |
| break_glass_user_arn | ARN of the break-glass IAM user. |
| break_glass_console_url | Console sign-in URL for the break-glass user (management account IAM user sign-in). |
| break_glass_initial_password | The initial console password for the break-glass user. The user MUST change this on first sign-in (password_reset_required is set). After first login, store the new password in the external vault and discard this value. Marked sensitive — retrieve with: `terraform output -raw break_glass_initial_password` |
| bookmarks_bucket | S3 bucket holding the break-glass switch-role page. |
| bookmarks_object_url | S3 console object the operator opens during an emergency. |
| refresh_lambda_name | Name of the bookmarks refresh Lambda (invoke manually to seed the first page). |
| alerts_topic_arn | SNS topic ARN (us-east-1) for break-glass usage alerts. |

## Security Notes

- The break-glass user has `AdministratorAccess` on the management account. SCPs do not apply to the management account, so compensating controls are critical:
  - No access keys (console + switch-role only)
  - MFA enforced by AdministratorAccess policy
  - Vault custody of credentials
  - Detective alerting on any activity
- All break-glass credentials and passwords should be stored in an external vault (e.g., HashiCorp Vault, 1Password, Keeper)
- The SNS topic is intentionally subscribed to the organization root email address to ensure visibility
- EventBridge alerting rules provide layered detection:
  - Console sign-in events
  - Cross-account role assumption
  - All mutating (write) API calls

For operational details and runbook procedures, see `BREAK_GLASS.md`.

## Module Structure

- `iam.tf` — Break-glass IAM user, initial password, and admin policy
- `bookmarks.tf` — Private S3 bucket holding the rendered switch-role HTML page
- `lambda.tf` — Refresh Lambda function and EventBridge triggers (Control Tower lifecycle + schedule)
- `monitoring.tf` — SNS topic, email subscription, and EventBridge alerting rules
- `main.tf` — Module documentation and resource breakdown
- `outputs.tf` — Module outputs
- `variables.tf` — Input variables with validation
- `versions.tf` — Terraform and provider version requirements
