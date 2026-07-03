###############################################################################
# Bookmarks bucket (CT management account, us-east-1)
#
# Holds the rendered breakglass.html switch-role page. Private, encrypted,
# versioned. Operators open it from the S3 console while signed in as the
# break-glass user. The refresh Lambda (lambda.tf) writes the object; Terraform
# only seeds an initial placeholder so the bucket is never empty before the
# first Lambda run.
###############################################################################

resource "aws_s3_bucket" "bookmarks" {
  provider = aws.org-management

  bucket = "break-glass-bookmarks-us-east-1-${var.ct_management_account_id}"

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "bookmarks" {
  provider = aws.org-management

  bucket                  = aws_s3_bucket.bookmarks.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bookmarks" {
  provider = aws.org-management

  bucket = aws_s3_bucket.bookmarks.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "bookmarks" {
  provider = aws.org-management

  bucket = aws_s3_bucket.bookmarks.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enforce TLS-only access to the bucket.
data "aws_iam_policy_document" "bookmarks" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.bookmarks.arn, "${aws_s3_bucket.bookmarks.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "bookmarks" {
  provider = aws.org-management

  bucket = aws_s3_bucket.bookmarks.id
  policy = data.aws_iam_policy_document.bookmarks.json
}

# Seed a placeholder so the page exists before the first Lambda invocation.
# After deploy, invoke the Lambda once (or wait for the first event/schedule)
# to populate the real list.
resource "aws_s3_object" "placeholder" {
  provider = aws.org-management

  bucket       = aws_s3_bucket.bookmarks.id
  key          = var.bookmarks_object_key
  content_type = "text/html; charset=utf-8"
  content      = <<-HTML
    <!DOCTYPE html>
    <html lang="en"><head><meta charset="utf-8"><title>Break-Glass Consoles</title></head>
    <body style="font-family: -apple-system, system-ui, sans-serif; max-width: 720px; margin: 2rem auto;">
      <h1>Break-Glass Consoles</h1>
      <p>Not yet generated. Invoke the <code>break-glass-refresh</code> Lambda
      in the management account, or wait for the next scheduled refresh.</p>
    </body></html>
  HTML

  # The Lambda owns this object's content on every run; ignore drift so Terraform
  # does not revert the live page back to the placeholder on subsequent applies.
  lifecycle {
    ignore_changes = [content, content_type, etag]
  }

  tags = var.tags
}
