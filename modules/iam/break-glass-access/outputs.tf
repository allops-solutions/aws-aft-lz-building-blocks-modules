output "break_glass_user_name" {
  description = "Name of the break-glass IAM user in the management account."
  value       = aws_iam_user.break_glass.name
}

output "break_glass_user_arn" {
  description = "ARN of the break-glass IAM user."
  value       = aws_iam_user.break_glass.arn
}

output "break_glass_console_url" {
  description = "Console sign-in URL for the break-glass user (management account IAM user sign-in)."
  value       = "https://${var.ct_management_account_id}.signin.aws.amazon.com/console"
}

output "break_glass_initial_password" {
  description = <<-EOT
    The initial console password for the break-glass user. The user MUST change
    this on first sign-in (password_reset_required is set). After first login,
    store the new password in the external vault and discard this value.
    Marked sensitive — retrieve with: terraform output -raw break_glass_initial_password
  EOT
  value       = aws_iam_user_login_profile.break_glass.password
  sensitive   = true
}

output "bookmarks_bucket" {
  description = "S3 bucket holding the break-glass switch-role page."
  value       = aws_s3_bucket.bookmarks.id
}

output "bookmarks_object_url" {
  description = "S3 console object the operator opens during an emergency."
  value       = "https://s3.console.aws.amazon.com/s3/object/${aws_s3_bucket.bookmarks.id}?region=us-east-1&prefix=${var.bookmarks_object_key}"
}

output "refresh_lambda_name" {
  description = "Name of the bookmarks refresh Lambda (invoke manually to seed the first page)."
  value       = aws_lambda_function.refresh.function_name
}

output "alerts_topic_arn" {
  description = "SNS topic ARN (us-east-1) for break-glass usage alerts."
  value       = aws_sns_topic.alerts.arn
}
