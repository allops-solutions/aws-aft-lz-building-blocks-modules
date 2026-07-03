"""
Break-glass bookmarks refresh.

Runs in the Control Tower management account. Enumerates all accounts in the
AWS Organization, determines which are governed by Control Tower (via
controltower:ListEnabledBaselines), and renders a static switch-role HTML page.

- CT-managed accounts → switch-role uses AWSControlTowerExecution
- Non-CT accounts (manually created) → switch-role uses OrganizationAccountAccessRole

The Lambda auto-discovers:
  1. The CT home region via controltower:ListLandingZones
  2. The AWSControlTowerBaseline ID via controltower:ListBaselines

Environment variables:
  BUCKET_NAME             target S3 bucket for the rendered page
  OBJECT_KEY              S3 key for the page (e.g. breakglass.html)
  TARGET_ROLE_NAME        CT role name (AWSControlTowerExecution)
  MGMT_ACCOUNT_ID         management account id (excluded from the list)
"""

import datetime
import html
import os

import boto3

ORG = boto3.client("organizations")
S3 = boto3.client("s3")

CT_ROLE = os.environ.get("TARGET_ROLE_NAME", "AWSControlTowerExecution")
ORG_ROLE = "OrganizationAccountAccessRole"


def _discover_ct_home_region():
    """
    Discover the Control Tower home region by calling ListLandingZones.
    The landing zone ARN format is:
      arn:aws:controltower:<region>:<account>:landingzone/<id>
    """
    ct = boto3.client("controltower", region_name="us-east-1")
    response = ct.list_landing_zones()
    landing_zones = response.get("landingZones", [])
    if landing_zones:
        arn = landing_zones[0]["arn"]
        return arn.split(":")[3]
    return None


def _discover_baseline_id(ct_region):
    """
    Discover the AWSControlTowerBaseline ID via ListBaselines.
    Returns the ID portion of the baseline ARN.
    """
    ct = boto3.client("controltower", region_name=ct_region)
    response = ct.list_baselines()
    for baseline in response.get("baselines", []):
        if baseline.get("name") == "AWSControlTowerBaseline":
            # ARN format: arn:aws:controltower:<region>::baseline/<id>
            return baseline["arn"].rsplit("/", 1)[-1]
    return None


def _ct_governed_account_ids():
    """
    Return the set of account IDs that are governed by Control Tower.

    Uses ListEnabledBaselines filtered on the AWSControlTowerBaseline.
    Targets that are OUs are resolved via organizations:ListAccountsForParent.
    """
    ct_region = _discover_ct_home_region()
    if not ct_region:
        return set()

    baseline_id = _discover_baseline_id(ct_region)
    if not baseline_id:
        return set()

    baseline_arn = f"arn:aws:controltower:{ct_region}::baseline/{baseline_id}"
    ct = boto3.client("controltower", region_name=ct_region)

    account_ids = set()
    ou_ids = set()

    paginator = ct.get_paginator("list_enabled_baselines")
    pages = paginator.paginate(
        filter={"baselineIdentifiers": [baseline_arn]}
    )
    for page in pages:
        for eb in page.get("enabledBaselines", []):
            target = eb.get("targetIdentifier", "")
            if ":account/" in target:
                account_ids.add(target.rsplit("/", 1)[-1])
            elif ":ou/" in target:
                ou_ids.add(target.rsplit("/", 1)[-1])

    # Resolve accounts in CT-registered OUs
    for ou_id in ou_ids:
        try:
            ou_paginator = ORG.get_paginator("list_accounts_for_parent")
            for page in ou_paginator.paginate(ParentId=ou_id):
                for acct in page["Accounts"]:
                    account_ids.add(acct["Id"])
        except Exception:
            pass

    return account_ids


def _all_accounts():
    """Return list of all accounts in the organization."""
    accounts = []
    paginator = ORG.get_paginator("list_accounts")
    for page in paginator.paginate():
        for acct in page["Accounts"]:
            accounts.append(acct)
    return accounts


def _collect():
    mgmt = os.environ["MGMT_ACCOUNT_ID"]
    ct_accounts = _ct_governed_account_ids()
    all_accounts = _all_accounts()

    rows = []
    for acct in all_accounts:
        acct_id = acct["Id"]
        if acct_id == mgmt:
            continue

        is_ct = acct_id in ct_accounts
        role = CT_ROLE if is_ct else ORG_ROLE

        rows.append(
            {
                "id": acct_id,
                "name": acct.get("Name", acct_id),
                "status": acct.get("Status", "UNKNOWN"),
                "role": role,
                "managed_by": "Control Tower" if is_ct else "Organizations",
            }
        )
    rows.sort(key=lambda r: r["name"].lower())
    return rows


def _render(rows):
    generated = datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%d %H:%M:%S UTC"
    )

    items = []
    if not rows:
        items.append(
            '<li class="empty">No accounts found in the organization.</li>'
        )
    for r in rows:
        name = html.escape(r["name"])
        acct_id = html.escape(r["id"])
        status = html.escape(r["status"])
        role = html.escape(r["role"])
        managed_by = html.escape(r["managed_by"])

        suspended = r["status"].upper() != "ACTIVE"
        badge_cls = "status suspended" if suspended else "status active"
        mgr_cls = "mgr ct" if r["managed_by"] == "Control Tower" else "mgr org"

        switch_url = (
            "https://signin.aws.amazon.com/switchrole"
            f"?roleName={html.escape(r['role'])}&account={acct_id}"
            f"&displayName={name}"
        )

        if suspended:
            action = '<span class="btn disabled">Unavailable</span>'
        else:
            action = f'<a class="btn" href="{switch_url}">Switch role</a>'

        items.append(
            f"""    <li>
      <div>
        <div class="name">{name}</div>
        <div class="meta">{acct_id} · {role}</div>
        <div class="meta"><span class="{mgr_cls}">{managed_by}</span></div>
      </div>
      <div class="right">
        <span class="{badge_cls}">{status}</span>
        {action}
      </div>
    </li>"""
        )

    items_html = "\n".join(items)

    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Break-Glass Consoles</title>
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
           max-width: 760px; margin: 2rem auto; padding: 0 1rem; color: #1d1d1f; }}
    h1 {{ font-weight: 600; }}
    p.note {{ color: #555; font-size: 0.9rem; }}
    .warn {{ background: #fff4e5; border: 1px solid #ffd8a8; border-radius: 8px;
             padding: 10px 14px; color: #8a5a00; font-size: 0.85rem; }}
    ul {{ list-style: none; padding: 0; }}
    li {{ border: 1px solid #e5e5ea; border-radius: 8px; padding: 12px 16px;
         margin-bottom: 10px; display: flex; justify-content: space-between; align-items: center; }}
    .name {{ font-weight: 600; }}
    .meta {{ color: #6e6e73; font-size: 0.8rem; }}
    .right {{ display: flex; align-items: center; gap: 12px; }}
    .status {{ font-size: 0.75rem; padding: 2px 8px; border-radius: 10px; }}
    .status.active {{ background: #e7f7ec; color: #1d7a3e; }}
    .status.suspended {{ background: #fde8e8; color: #b42318; }}
    .mgr {{ font-size: 0.7rem; padding: 2px 6px; border-radius: 8px; }}
    .mgr.ct {{ background: #e8f0fe; color: #1a56db; }}
    .mgr.org {{ background: #f3e8ff; color: #7c3aed; }}
    a.btn {{ background: #0071e3; color: white; padding: 8px 16px; border-radius: 6px;
            text-decoration: none; font-size: 0.9rem; }}
    a.btn:hover {{ background: #0058b8; }}
    .btn.disabled {{ background: #e5e5ea; color: #8e8e93; padding: 8px 16px;
                     border-radius: 6px; font-size: 0.9rem; }}
    .empty {{ color: #888; font-style: italic; padding: 1rem 0; }}
    footer {{ margin-top: 2rem; color: #888; font-size: 0.8rem; }}
    .legend {{ display: flex; gap: 1rem; margin-bottom: 1rem; font-size: 0.8rem; }}
    .legend span {{ padding: 2px 8px; border-radius: 8px; }}
  </style>
</head>
<body>
  <h1>Break-Glass Consoles</h1>
  <p class="warn">
    <strong>Emergency use only.</strong> Sign in as the break-glass IAM user in the
    management account (credentials in the vault), then click an account below to assume
    the appropriate role. Every use is logged and alerted. Follow BREAK_GLASS.md
    and return to normal operations afterward.
  </p>
  <p class="note">
    Accounts managed by Control Tower use <code>{html.escape(CT_ROLE)}</code>.
    Other accounts use <code>{html.escape(ORG_ROLE)}</code>.
  </p>
  <div class="legend">
    <span class="mgr ct">Control Tower</span>
    <span class="mgr org">Organizations</span>
  </div>

  <ul>
{items_html}
  </ul>

  <footer>
    Generated {generated}. Source: organizations:ListAccounts + controltower:ListEnabledBaselines.
  </footer>
</body>
</html>
"""


def handler(event, context):
    rows = _collect()
    page = _render(rows)
    S3.put_object(
        Bucket=os.environ["BUCKET_NAME"],
        Key=os.environ["OBJECT_KEY"],
        Body=page.encode("utf-8"),
        ContentType="text/html; charset=utf-8",
    )
    return {
        "statusCode": 200,
        "accounts_listed": len(rows),
        "ct_managed": sum(1 for r in rows if r["managed_by"] == "Control Tower"),
        "org_managed": sum(1 for r in rows if r["managed_by"] == "Organizations"),
        "object": f"s3://{os.environ['BUCKET_NAME']}/{os.environ['OBJECT_KEY']}",
    }
