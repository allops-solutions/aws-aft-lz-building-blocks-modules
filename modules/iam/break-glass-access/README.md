# iam/break-glass-access

Emergency ("break-glass") access for AWS Control Tower environments.

This module provisions a dormant, console-only IAM user in the Control Tower management account that can assume `AWSControlTowerExecution` in every enrolled account when IAM Identity Center and/or the external IdP are unavailable. A Lambda function automatically maintains a switch-role bookmarks page listing all accounts, and layered EventBridge rules alert on any break-glass user activity via SNS email.

All resources are deployed exclusively in **us-east-1** via the `aws.org-management` provider alias.

## Usage

```hcl
module "break_glass" {
  source = "./modules/iam/break-glass-access"

  providers = {
    aws.org-management = aws.org-management
  }

  ct_management_account_id = "123456789012"
  notification_email       = "aws-root@example.com"
  enable_centralized_logging = true

  tags = {
    Environment = "management"
    ManagedBy   = "terraform"
  }
}
```

### Post-Deploy Steps

1. **Confirm the SNS subscription** — Check the notification email inbox and click the confirmation link.
2. **Seed the bookmarks page** — Invoke the `break-glass-refresh` Lambda once:
   ```bash
   aws lambda invoke --function-name break-glass-refresh /dev/stdout
   ```
3. **Bootstrap credentials** — Retrieve the initial password from SSM, sign in, change the password (forced), enroll MFA, and store final credentials in your vault:
   ```bash
   aws ssm get-parameter \
     --name "/break-glass/initial-password" \
     --with-decryption \
     --query "Parameter.Value" \
     --output text
   ```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| aws | >= 6.0.0 |
| archive | >= 2.0.0 |
| random | >= 3.0.0 |

## Providers

| Name | Description |
|------|-------------|
| `aws.org-management` | AWS provider configured for the Control Tower management account in us-east-1 (assumes AWSAFTExecution). |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `ct_management_account_id` | The Control Tower / Organizations management account ID. All break-glass resources are created here. | `string` | — | yes |
| `notification_email` | Email address subscribed to the break-glass usage SNS topic. Should be the same closely-held distribution list as the organization root user. The subscription must be confirmed once via email. | `string` | — | yes |
| `tags` | Tags to apply to all resources. Passed in from the root module. | `map(string)` | — | yes |
| `break_glass_user_name` | Name of the single break-glass IAM user created in the management account. | `string` | `"break-glass-user"` | no |
| `target_role_name` | The role the break-glass user switches into within each Control Tower-managed account. Do not change unless your landing zone uses a different execution role. | `string` | `"AWSControlTowerExecution"` | no |
| `refresh_schedule_expression` | EventBridge schedule for the periodic bookmarks refresh (covers account suspensions). | `string` | `"rate(7 days)"` | no |
| `bookmarks_object_key` | S3 object key for the rendered break-glass bookmarks HTML page. | `string` | `"breakglass.html"` | no |
| `enable_centralized_logging` | Whether Control Tower centralized logging (organization CloudTrail trail) is enabled. When true, no extra trail is created. When false, a minimal multi-region trail is created for EventBridge delivery. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| `break_glass_user_name` | Name of the break-glass IAM user in the management account. |
| `break_glass_user_arn` | ARN of the break-glass IAM user. |
| `break_glass_console_url` | Console sign-in URL for the break-glass user (management account IAM user sign-in). |
| `break_glass_initial_password` | The initial console password (sensitive). Retrieve with `terraform output -raw break_glass_initial_password`. Must be changed on first login. |
| `bookmarks_bucket` | S3 bucket holding the break-glass switch-role page. |
| `bookmarks_object_url` | S3 console URL for the bookmarks object the operator opens during an emergency. |
| `refresh_lambda_name` | Name of the bookmarks refresh Lambda (invoke manually to seed the first page). |
| `alerts_topic_arn` | SNS topic ARN (us-east-1) for break-glass usage alerts. |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   Management Account (us-east-1)                │
│                                                                 │
│  ┌──────────────┐     ┌─────────────────┐     ┌─────────────┐  │
│  │  IAM User    │     │  Lambda         │     │  S3 Bucket   │  │
│  │  (dormant)   │     │  (refresh)      │────▶│  (bookmarks) │  │
│  └──────────────┘     └─────────────────┘     └─────────────┘  │
│                              ▲                                   │
│                              │                                   │
│  ┌───────────────────────────┴───────────────────────────────┐  │
│  │              EventBridge Rules                             │  │
│  │  • CT lifecycle (CreateManagedAccount/UpdateManagedAccount)│  │
│  │  • Periodic schedule (default: weekly)                    │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Detective Alerting                            │  │
│  │  • Console sign-in ──┐                                    │  │
│  │  • AssumeRole ───────┼──▶ SNS Topic ──▶ Email             │  │
│  │  • Write ops ────────┘                                    │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Security Considerations

- **No access keys** — The break-glass user is console-only; switch-role is the only mechanism to reach other accounts.
- **SCPs do not apply** to the management account. Compensating controls are: vault custody of credentials, forced password reset, and detective alerting on all activity.
- **Least-privilege Lambda** — The refresh function can only read Organizations/Control Tower metadata and write a single S3 object.
- **TLS enforced** — The bookmarks bucket denies non-HTTPS requests.

## License

Internal module — see organizational policies for usage and distribution terms.
