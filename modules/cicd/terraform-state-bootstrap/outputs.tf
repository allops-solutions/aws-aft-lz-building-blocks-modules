# ==============================================================================
# Terraform State Bootstrap Module — Outputs
# ==============================================================================

output "bucket_name" {
  description = "Name of the Terraform state S3 bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the Terraform state S3 bucket."
  value       = aws_s3_bucket.this.arn
}
