# Break-Glass Access Terraform Module

Emergency access for AWS Control Tower environments when IAM Identity Center and/or the external IdP are unavailable.

## Overview

This module provisions a secure break-glass access solution in the Control Tower management account. It provides:

- **Single emergency IAM user** with AdministratorAccess in the management account, accessible only via console (no access keys)
- **Auto-generated switch-role bookmarks page** stored in a private S3 bucket, listing all Control Tower-managed accounts for rapid role assumption
- **Automated refresh Lambda** triggered by Control Tower account lifecycle events and on a configurable periodic schedule (to detect account suspensions)
- **Three-layer alerting** via SNS/email for any console sign-in, cross-account role assumption, or mutating API call by the break-glass user
- **Conditional CloudTrail trail** for EventBridge event delivery (when Control Tower centralized logging is not enabled)

**All resources are deployed exclusively in `us-east-1`**, as console sign-in events are global and only delivered there.

## Usage

```hcl
# Example: instantiate in the aft-management account customization

module "break_glass_access" {
  source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/iam/break-glass-access?ref=iam-break-glass-access-v1.0"

  ct_management_account_id    = "123456789012"
  notification_email          = "aws-root@example.com"
  enable_centralized_logging  = true  # Set to true if CT org trail is enabled

  tags = {
    Environment = "management"
    Purpose     = "emergency-access"
  }

  # Optional: override defaults
  break_glass_user_name      = "break-glass-user"           # default
  target_role_name           = "AWSControlTowerExecution"   # default
  refresh_schedule_expression = "rate(7 days)"              # default
  bookmarks_object_key       = "breakglass.html"            # default

  # Pin to a specific version
  # source = "github.com/allops-solutions/aws-aft-lz-building-blocks-modules//modules/iam/break-glass-access?ref=iam-break-glass-access-v1.0"
}

# Retrieve break-glass initial password from SSM Parameter Store
output "break_glass_credentials" {
  value = "Run: aws ssm get-parameter --name '/break-glass/initial-password' --with-decryption --query 'Parameter.Value' --output text"
}
```

## Requirements

| Requirement | Version |
| --- | --- |
| Terraform | `>= 1.6.0` |

## Providers

| Provider | Version | Notes |
| --- | --- | --- |
| aws | `>= 6.23.0` | Requires `aws.org-management` alias configured for the Control Tower management account in `us-east-1` |
| archive | `>= 2.0.0` | Packages the refresh Lambda function |
| random | `>= 3.0.0` | Generates the initial break-glass user password |

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | --- |
| `ct_management_account_id` | The Control Tower / Organizations management account ID. All break-glass resources are created here. | `string` | N/A | Yes |
| `notification_email` | Email address subscribed to the break-glass usage SNS topic. This is intentionally the same mailbox as the organization root user (e.g. `aws-root@example.com`) so that break-glass activity is visible to the same closely-held distribution list. The subscription must be confirmed once by clicking the link in the confirmation email. | `string` | N/A | Yes |
| `break_glass_user_name` | Name of the single break-glass IAM user created in the management account. | `string` | `"break-glass-user"` | No |
| `notification_email` | Email address subscribed to the break-glass usage SNS topic. This is intentionally the same mailbox as the organization root user (e.g. `aws-root@example.com`) so that break-glass activity is visible to the same closely-held distribution list. The subscription must be confirmed once by clicking the link in the confirmation email. | `string` | N/A | Yes |
| `target_role_name` | The role the break-glass user switches into within each Control Tower-managed account. `AWSControlTowerExecution` exists in every CT-enrolled account, grants `AdministratorAccess`, and trusts the management account. Do not change unless your landing zone uses a different execution role. | `string` | `"AWSControlTowerExecution"` | No |
| `refresh_schedule_expression` | EventBridge schedule for the periodic bookmarks refresh (covers account suspensions, for which there is no event trigger). Defaults to weekly. | `string` | `"rate(7 days)"` | No |
| `bookmarks_object_key` | S3 object key for the rendered break-glass bookmarks HTML page. | `string` | `"breakglass.html"` | No |
| `enable_centralized_logging` | Whether Control Tower centralized logging (organization CloudTrail trail) is enabled. When `true`, the CT org trail provides EventBridge delivery — no extra trail is created. When `false`, this module creates a minimal multi-region CloudTrail trail in the management account to ensure EventBridge can receive sign-in events for alerting. | `bool` | `false` | No |
| `tags` | Tags to apply to all resources. Passed in from the root module — do not set defaults here. | `map(string)` | N/A | Yes |

## Outputs

| Name | Description |
| --- | --- |
| `break_glass_user_name` | Name of the break-glass IAM user in the management account. |
| `break_glass_user_arn` | ARN of the break-glass IAM user. |
| `break_glass_console_url` | Console sign-in URL for the break-glass user (management account IAM user sign-in). |
| `break_glass_initial_password` | The initial console password for the break-glass user. The user **MUST** change this on first sign-in. After first login, store the new password in the external vault and discard this value. Marked sensitive — retrieve with: `terraform output -raw break_glass_initial_password` |
| `bookmarks_bucket` | S3 bucket holding the break-glass switch-role page. |
| `bookmarks_object_url` | S3 console object the operator opens during an emergency. |
| `refresh_lambda_name` | Name of the bookmarks refresh Lambda (invoke manually to seed the first page). |
| `alerts_topic_arn` | SNS topic ARN (us-east-1) for break-glass usage alerts. |

## Architecture & Security

All resources are deployed in `us-east-1` because:
- Console sign-in events are delivered globally **only** to `us-east-1`
- EventBridge rules, SNS topic, bookmarks bucket, and refresh Lambda must coexist with these events

### Key Security Features

1. **Console-only access**: No access keys; emergency access requires console MFA enrollment
2. **Forced password change**: Initial password auto-generated; user must change on first sign-in
3. **Credential vault storage**: Initial credentials stored in SSM Parameter Store (SecureString) for central retrieval
4. **Full administrative access**: `AdministratorAccess` policy ensures the user is not blocked during an incident
5. **No SCP protection on management account**: Compensating controls are MFA enforcement, vault custody of credentials, and detective alerting
6. **Three-layer event alerting**:
   - Console sign-in detection (any login attempt)
   - Cross-account role assumption (AssumeRole calls to other accounts)
   - Mutating (write) API operations (excludes read-only calls and KMS crypto operations)
7. **Automatic bookmarks refresh**: Lambda regenerates the switch-role page on:
   - Control Tower account creation/update events
   - Periodic schedule (default weekly) to pick up account suspensions

## Implementation Details

### File Organization

- **iam.tf**: Break-glass IAM user, login profile, SSM parameter storage, and AdministratorAccess policy
- **bookmarks.tf**: Private, encrypted, versioned S3 bucket with TLS-only access enforcement; seeded with placeholder HTML
- **lambda.tf**: Refresh Lambda function, execution role/policy, EventBridge rules (CT lifecycle and schedule), and Lambda permissions
- **monitoring.tf**: SNS alerting topic, three EventBridge alert rules (sign-in, assume-role, write ops), and conditional CloudTrail trail

### Lambda Function

The refresh Lambda enumerates all Control Tower-enrolled accounts and generates an HTML page with switch-role URLs for each account. It:
- Calls `organizations:ListAccounts` and `controltower:ListLandingZones`
- Generates pre-signed or direct switch-role URLs to the target role in each account
- Writes the rendered HTML to the bookmarks S3 object
- Runs with a 120-second timeout and 256 MB memory on ARM64 architecture

### EventBridge Alerting

All events are detected via CloudTrail and delivered to EventBridge in `us-east-1`. The three rules are:

1. **Console sign-in**: Triggered on any `ConsoleLogin` event by the break-glass user
2. **Cross-account assume**: Triggered on `AssumeRole`, `AssumeRoleWithSAML`, or `AssumeRoleWithWebIdentity` by the break-glass user
3. **Write operations**: Triggered on any API call with `readOnly=false`, excluding STS assume-role events and KMS crypto operations

All matching events publish structured alerts to the SNS topic with context (timestamp, source IP, account, event type).

## Prerequisites

1. **Control Tower landing zone** already deployed and enrolled
2. **Management account access**: Module must be instantiated via AFT customization or direct Terraform deployment in the management account
3. **AWS provider alias**: `aws.org-management` must be configured to assume `AWSAFTExecution` in the management account for `us-east-1`
4. **Email confirmation**: The operator must confirm the SNS email subscription for alerts to be delivered
5. **Optional**: If Control Tower centralized logging is enabled, this module reuses the existing CT organization trail; otherwise it creates a minimal trail

## Operational Notes

1. **First deployment**: After Terraform apply, invoke the refresh Lambda manually to generate the initial bookmarks page:
   ```bash
   aws lambda invoke --function-name break-glass-refresh /dev/null --region us-east-1
   ```
   Or wait for the first scheduled invocation.

2. **Retrieving initial credentials**:
   ```bash
   aws ssm get-parameter \
     --name "/break-glass/initial-password" \
     --with-decryption \
     --query "Parameter.Value" \
     --output text
   ```

3. **Password change**: The break-glass user must change the initial password on first sign-in. After that, Terraform ignores drift on the password to preserve the user-set value.

4. **Monitoring**: All break-glass user activity triggers SNS alerts to the notification email. Treat unexpected activity as a potential compromise.

5. **Account status changes**: The refresh Lambda runs on a schedule (default weekly) to detect suspended or re-activated accounts. Manual invocation can refresh immediately if needed.

## Related Modules

- `aws-aft-lz-building-blocks-modules/modules/network/ipam` — IPAM allocation for landing zone
- `aws-aft-lz-building-blocks-modules/modules/logging/centralized-logging` — Centralized logging for the organization
