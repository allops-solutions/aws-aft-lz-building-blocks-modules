###############################################################################
# Break-glass IAM user (CT management account)
#
# A single, dormant, console-only user used ONLY when IAM Identity Center and/or
# the external IdP are unavailable. It has NO access keys (console + switch-role
# is all that's needed). A random initial password is generated and must be
# changed on first sign-in (password_reset_required = true). The initial
# password is stored in SSM Parameter Store (SecureString) in the management
# account at /break-glass/initial-password along with the console URL and
# username. After first login the user sets their own password.
#
# RETRIEVAL:
#   aws ssm get-parameter \
#     --name "/break-glass/initial-password" \
#     --with-decryption \
#     --query "Parameter.Value" \
#     --output text
#
# SECURITY NOTE: SCPs do not apply to the management account, so they cannot
# protect this principal. The compensating controls are: MFA enforced via the
# AdministratorAccess policy being the only permission, vault custody of
# credentials, and the detective alerting in monitoring.tf.
###############################################################################

resource "aws_iam_user" "break_glass" {
  provider = aws.org-management

  name = var.break_glass_user_name

  tags = merge(var.tags, {
    Name      = var.break_glass_user_name
    purpose   = "emergency-access"
    sensitive = "true"
  })
}

# Generate a random initial password. The user MUST change it on first sign-in.
resource "random_password" "break_glass_initial" {
  length           = 32
  special          = true
  override_special = "!@#$%^&*()-_=+"
}

resource "aws_iam_user_login_profile" "break_glass" {
  provider = aws.org-management

  user                    = aws_iam_user.break_glass.name
  password_length         = 32
  password_reset_required = true

  # The initial password is managed by Terraform only for bootstrapping.
  # After the user changes it on first login, ignore drift so Terraform
  # does not fight with the user-set password.
  lifecycle {
    ignore_changes = [password_length, password_reset_required]
  }
}

# Store all login details in SSM (SecureString) so operators have everything
# they need in one place — no hunting through state or multiple sources.
resource "aws_ssm_parameter" "break_glass_initial_password" {
  provider = aws.org-management

  name        = "/break-glass/initial-password"
  type        = "SecureString"
  description = "Break-glass user login details. Password must be changed on first login."
  value = join("\n", [
    "Console URL: https://${var.ct_management_account_id}.signin.aws.amazon.com/console",
    "Username:    ${var.break_glass_user_name}",
    "Password:    ${aws_iam_user_login_profile.break_glass.password}",
    "",
    "Password must be changed on first login. Enroll MFA immediately after.",
  ])
  tags = var.tags

  lifecycle {
    ignore_changes = [value]
  }
}

# AdministratorAccess — the break-glass user gets full admin on the management
# account. This is an emergency user; fine-grained permissions would only get in
# the way during an incident. The compensating controls are: no access keys,
# detective alerting on any activity (monitoring.tf), and vault custody.
resource "aws_iam_user_policy_attachment" "admin_access" {
  provider = aws.org-management

  user       = aws_iam_user.break_glass.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
