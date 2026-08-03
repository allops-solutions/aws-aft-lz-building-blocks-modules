# Lambda Test Events

This Lambda is invoked by EventBridge on `Security Hub Findings - Imported`
events and decides delivery **per product**, keyed on the ASFF `ProductName`
field (never on the EventBridge `source`, which is always `aws.securityhub` for
every imported finding, no matter which service produced it):

- **`ProductName` = "Security Hub"** (the account's own control/CSPM findings) →
  throttled by the `securityhub` policy: notify on the first-observed day, send a
  monthly reminder on the 1st of the month, otherwise suppress. Controls are
  re-imported on every AWS Config re-evaluation, so this stops one unresolved
  control from mailing every day.
- **Any other product** (GuardDuty, Inspector, Macie, IAM Access Analyzer, ...) →
  always notify, regardless of dates.

The EventBridge rule also applies a severity floor (`notification_min_severity`,
default `HIGH`) to **every** product before the Lambda ever runs. A finding below
the floor is dropped by the rule and never reaches the function.

**Replace placeholders throughout:** `eu-central-1` (Region), `ACCOUNT_ID`
(Account ID), `securityhub-finding-notifications-formatter` (function name if
yours differs).

---

## Which test method to use

| # | Method | Realism | What it actually exercises |
|---|--------|---------|----------------------------|
| 1 | `guardduty create-sample-findings` | **Real end to end.** Real GuardDuty findings flow through Security Hub → EventBridge → Lambda → SNS. | The "non-control product always notifies" path, and the severity floor, for real. |
| 2 | `securityhub batch-import-findings` (default product) | Real pipeline, synthetic finding. Product is forced to `Default` (see note). | The EventBridge → Lambda → SNS wiring. Always delivered; does **not** touch the suppression policy. |
| 3 | `lambda invoke` with a crafted ASFF event | Unit test. Bypasses EventBridge/GuardDuty. | The `securityhub` suppression policy and per-product routing, which cannot be driven any other way (see note). |

> **Why you can't test everything through the real pipeline.** Security Hub
> derives `ProductName`/`CompanyName` from the `ProductArn`; you cannot set them
> with `batch-import-findings` unless you register a custom integration. Imports
> through the account's default product ARN are always labelled `Default`, so they
> never match the `Security Hub` control policy. And a real control finding only
> re-imports across days on its own Config schedule, which you can't force on
> demand. That is why the suppression logic (tests in section 3) is exercised by
> invoking the Lambda directly with a payload shaped like a real
> `Security Hub Findings - Imported` event.

---

## 1. Real end-to-end GuardDuty test (recommended)

Generates genuine GuardDuty sample findings. With the integration enabled (this
account is the Security Hub delegated admin), they are converted to ASFF, land in
Security Hub with `ProductName: "GuardDuty"`, and trigger the pipeline. Because
GuardDuty is not a control product, every one that clears the severity floor is
delivered.

```bash
# 1. Find the detector in the account/Region you want to test from.
DETECTOR=$(aws guardduty list-detectors --region eu-central-1 \
  --query 'DetectorIds[0]' --output text)

# 2. Generate HIGH-severity sample findings so they clear the default HIGH floor.
#    (Severity varies by type; the two below map to HIGH in ASFF. Omit
#    --finding-types to generate one sample of every type, but note only the
#    HIGH/CRITICAL ones will reach the Lambda.)
aws guardduty create-sample-findings \
  --region eu-central-1 \
  --detector-id "$DETECTOR" \
  --finding-types \
    'Backdoor:EC2/C&CActivity.B!DNS' \
    'CryptoCurrency:EC2/BitcoinTool.B!DNS'
```

> **Note (zsh/bash):** finding-type strings are wrapped in **single** quotes
> because the `!` in `B!DNS` triggers history expansion (`zsh: event not found:
> DNS`) inside double quotes. Keep `"$DETECTOR"` in double quotes so the variable
> still expands.

**Expected (2–5 min later):** an email per finding, standard framing,
`[HIGH] GuardDuty: [SAMPLE] ...` subject. Confirm in the formatter's CloudWatch
log group: `product=GuardDuty ... type=standard`. Sample findings carry
`Sample: true` and a `[SAMPLE]` title prefix but are otherwise processed normally.

### 1b. Real LOW/MEDIUM findings are dropped by the severity floor

This validates the other side: a genuine below-floor GuardDuty finding lands in
Security Hub but never reaches the Lambda, so no email is sent. Note this is *not*
the Lambda's date-based suppression — the EventBridge rule filters it out one step
earlier, before the function is invoked.

```bash
DETECTOR=0a5701d91e7b4273bdc057ce871ed0bc

# Recon:EC2/PortProbeUnprotectedPort is a LOW-severity type. Add other types if
# you also want a MEDIUM sample — the verification step below tells you the label.
aws guardduty create-sample-findings \
  --region eu-central-1 \
  --detector-id "$DETECTOR" \
  --finding-types "Recon:EC2/PortProbeUnprotectedPort"
```

**Verify (wait 2–5 min):**

1. It reached Security Hub with a below-`HIGH` label — confirms GuardDuty → Security
   Hub still works, and shows the exact `Severity.Label` the floor evaluates:

   ```bash
   aws securityhub get-findings --region eu-central-1 \
     --filters '{"ProductName":[{"Value":"GuardDuty","Comparison":"EQUALS"}],
                 "Title":[{"Value":"PortProbeUnprotectedPort","Comparison":"PREFIX"}]}' \
     --query 'Findings[].{Id:Id,Severity:Severity.Label,Sample:Sample,Title:Title}' \
     --output table
   ```

   Expect `LOW` (or `MEDIUM` for other types). Copy the finding `Id`.

2. The Lambda was **not** invoked for it — no log line references its Id:

   ```bash
   aws logs filter-log-events --region eu-central-1 \
     --log-group-name /aws/lambda/securityhub-finding-notifications-formatter \
     --start-time $(( ($(date +%s) - 1800) * 1000 )) \
     --filter-pattern '"<paste-finding-id-here>"'
   ```

   Expect **zero events**. Empty output means EventBridge filtered the finding on
   severity before it ever reached the function — exactly the intended behavior.
   (A HIGH finding from test 1, by contrast, would show a `product=GuardDuty ...
   type=standard` line here.)

> If step 1 shows the label as `HIGH`/`CRITICAL`, GuardDuty has re-rated that type;
> pick another and re-check. The label in step 1 is the source of truth for what
> the floor lets through, not the type name.

---

## 2. Pipeline smoke test (`batch-import-findings`)

Pushes a synthetic finding through the real EventBridge → Lambda → SNS path
without any AWS service involved. Useful to confirm the wiring, SNS subscription,
and formatting. The finding's product is `Default`, so it is always delivered and
never exercises the suppression policy.

```bash
aws securityhub batch-import-findings --region eu-central-1 --findings '[{
  "SchemaVersion":"2018-10-08",
  "Id":"test-pipeline-smoke-001",
  "ProductArn":"arn:aws:securityhub:eu-central-1:ACCOUNT_ID:product/ACCOUNT_ID/default",
  "GeneratorId":"manual-pipeline-test",
  "AwsAccountId":"ACCOUNT_ID",
  "AwsAccountName":"security-audit",
  "Types":["Software and Configuration Checks/Industry and Regulatory Standards"],
  "CreatedAt":"2026-07-28T09:00:00.000Z",
  "UpdatedAt":"2026-07-28T09:00:00.000Z",
  "FirstObservedAt":"2026-07-28T09:00:00.000Z",
  "Severity":{"Label":"HIGH"},
  "Title":"TEST - pipeline smoke test",
  "Description":"Synthetic finding to validate EventBridge -> Lambda -> SNS. Product is Default, so it is always delivered.",
  "Resources":[{"Type":"AwsAccount","Id":"AWS::::Account:ACCOUNT_ID"}],
  "RecordState":"ACTIVE",
  "Workflow":{"Status":"NEW"},
  "Compliance":{"Status":"FAILED"}
}]'
```

**Expected:** one email, `[HIGH] Default: TEST - pipeline smoke test`. The severity
must be at or above `notification_min_severity` (default `HIGH`) or the rule drops
it before the Lambda runs — set `"Severity":{"Label":"LOW"}` to confirm the floor
(no email, no Lambda log line).

---

## 3. Suppression policy unit tests (`lambda invoke`)

These drive the notification policy directly. They bypass EventBridge (so the
severity floor does not apply here — use realistic severities anyway) and set
`ProductName` explicitly to route to the policy under test. Each payload mirrors a
real `Security Hub Findings - Imported` event: full ASFF findings inside
`detail.findings`, envelope `source` = `aws.securityhub`.

### 3a. Control finding, first observed today → delivered `[NEW]`

```bash
aws lambda invoke --function-name securityhub-finding-notifications-formatter \
  --cli-binary-format raw-in-base64-out --payload '{
  "source":"aws.securityhub",
  "detail-type":"Security Hub Findings - Imported",
  "detail":{"findings":[{
    "SchemaVersion":"2018-10-08",
    "Id":"arn:aws:securityhub:eu-central-1:ACCOUNT_ID:subscription/aws-foundational-security-best-practices/v/1.0.0/IAM.1/finding/test-sh-new",
    "ProductArn":"arn:aws:securityhub:eu-central-1::product/aws/securityhub",
    "ProductName":"Security Hub",
    "CompanyName":"AWS",
    "GeneratorId":"aws-foundational-security-best-practices/v/1.0.0/IAM.1",
    "AwsAccountId":"ACCOUNT_ID",
    "AwsAccountName":"security-audit",
    "Region":"eu-central-1",
    "Types":["Software and Configuration Checks/Industry and Regulatory Standards/AWS-Foundational-Security-Best-Practices"],
    "CreatedAt":"2026-07-28T09:00:00.000Z",
    "UpdatedAt":"2026-07-28T09:00:00.000Z",
    "FirstObservedAt":"2026-07-28T09:00:00.000Z",
    "Severity":{"Label":"HIGH"},
    "Title":"TEST - control finding first observed today",
    "Description":"FirstObservedAt == UpdatedAt -> delivered with [NEW] framing.",
    "Resources":[{"Type":"AwsIamPolicy","Id":"arn:aws:iam::ACCOUNT_ID:policy/test"}],
    "RecordState":"ACTIVE",
    "Workflow":{"Status":"NEW"},
    "Compliance":{"Status":"FAILED"}
  }]}
}' output.json && cat output.json
```

**Expected:** `[NEW]` header, `[NEW] [HIGH] Security Hub: ...` subject,
`notifications_published=1`.

### 3b. Control finding, old and not the 1st → suppressed

Same payload as 3a with these fields changed:

```json
"Id":".../finding/test-sh-old",
"CreatedAt":"2026-07-20T12:00:00.000Z",
"FirstObservedAt":"2026-07-20T12:00:00.000Z",
"UpdatedAt":"2026-07-28T11:00:00.000Z"
```

**Expected:** no email, `notifications_suppressed=1`.

### 3c. Control finding, UpdatedAt on the 1st → monthly reminder

Same payload as 3a with these fields changed:

```json
"Id":".../finding/test-sh-reminder",
"CreatedAt":"2026-06-15T08:00:00.000Z",
"FirstObservedAt":"2026-06-15T08:00:00.000Z",
"UpdatedAt":"2026-07-01T10:00:00.000Z",
"Severity":{"Label":"CRITICAL"}
```

**Expected:** `[REMINDER]` header, `[REMINDER] [CRITICAL] Security Hub: ...`
subject.

### 3d. GuardDuty finding, old and not the 1st → still delivered

This is the key regression check for "GuardDuty always notifies": the same dates
that suppress a control finding in 3b must **not** suppress a GuardDuty finding.

```bash
aws lambda invoke --function-name securityhub-finding-notifications-formatter \
  --cli-binary-format raw-in-base64-out --payload '{
  "source":"aws.securityhub",
  "detail-type":"Security Hub Findings - Imported",
  "detail":{"findings":[{
    "SchemaVersion":"2018-10-08",
    "Id":"arn:aws:guardduty:eu-central-1:ACCOUNT_ID:detector/abc/finding/test-gd-old",
    "ProductArn":"arn:aws:securityhub:eu-central-1::product/aws/guardduty",
    "ProductName":"GuardDuty",
    "CompanyName":"Amazon",
    "GeneratorId":"arn:aws:guardduty:eu-central-1:ACCOUNT_ID:detector/abc",
    "AwsAccountId":"ACCOUNT_ID",
    "AwsAccountName":"production",
    "Region":"eu-central-1",
    "Types":["TTPs/Command and Control/Backdoor:EC2-C&CActivity.B!DNS"],
    "CreatedAt":"2026-07-01T12:00:00.000Z",
    "UpdatedAt":"2026-07-28T14:00:00.000Z",
    "FirstObservedAt":"2026-07-01T12:00:00.000Z",
    "Severity":{"Label":"HIGH"},
    "Title":"TEST - GuardDuty finding first observed weeks ago",
    "Description":"Not a control product -> always delivered, even though it is old and not the 1st.",
    "Resources":[{"Type":"AwsEc2Instance","Id":"i-1234567890abcdef0"}],
    "RecordState":"ACTIVE",
    "Workflow":{"Status":"NEW"}
  }]}
}' output.json && cat output.json
```

**Expected:** delivered, standard `[HIGH] GuardDuty: ...` subject,
`notifications_published=1`.

### 3e. Mixed batch → control suppressed, GuardDuty delivered

Put two findings in one `detail.findings` array: the control finding from 3b
(old dates) and the GuardDuty finding from 3d (old dates).

**Expected:** `notifications_published=1`, `notifications_suppressed=1` — the
GuardDuty one is delivered, the control one is suppressed.

---

## Summary

| Test | Method | Realism | ProductName | Delivered? | Framing |
|------|--------|---------|-------------|-----------|---------|
| 1  | `create-sample-findings` | real end to end | GuardDuty | ✅ (if ≥ floor) | standard |
| 1b | `create-sample-findings` (LOW/MEDIUM) | real end to end | GuardDuty | ❌ dropped by EventBridge floor | — |
| 2  | `batch-import-findings`  | real pipeline / synthetic | Default | ✅ | standard |
| 3a | `lambda invoke` | unit test | Security Hub | ✅ | `[NEW]` |
| 3b | `lambda invoke` | unit test | Security Hub | ❌ suppressed | — |
| 3c | `lambda invoke` | unit test | Security Hub | ✅ | `[REMINDER]` |
| 3d | `lambda invoke` | unit test | GuardDuty | ✅ | standard |
| 3e | `lambda invoke` | unit test | mixed | partial | 1 delivered, 1 suppressed |
