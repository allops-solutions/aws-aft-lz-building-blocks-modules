# =============================================================================
# Artifact bucket
#
# CodePipeline needs somewhere to hand artifacts between actions. Terraform plan
# files do NOT live here -- they go to the state bucket in the target account,
# under the _plans prefix, so that the artefact a human approved and the artefact
# an apply consumes are in the account that owns the state.
# =============================================================================

locals {
  artifact_bucket        = var.artifact_bucket_name != null ? var.artifact_bucket_name : aws_s3_bucket.artifacts[0].bucket
  create_artifact_bucket = var.artifact_bucket_name == null
}

resource "aws_s3_bucket" "artifacts" {
  count = local.create_artifact_bucket ? 1 : 0

  bucket = "${local.pipeline_name}-artifacts-${local.account_id}"
  tags   = var.tags
}

resource "aws_s3_bucket_ownership_controls" "artifacts" {
  count = local.create_artifact_bucket ? 1 : 0

  bucket = aws_s3_bucket.artifacts[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  count = local.create_artifact_bucket ? 1 : 0

  bucket = aws_s3_bucket.artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  count = local.create_artifact_bucket ? 1 : 0

  bucket = aws_s3_bucket.artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  count = local.create_artifact_bucket ? 1 : 0

  bucket = aws_s3_bucket.artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  count = local.create_artifact_bucket ? 1 : 0

  bucket = aws_s3_bucket.artifacts[0].id

  rule {
    id     = "expire-artifacts"
    status = "Enabled"

    filter {}

    expiration {
      days = var.artifact_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.artifact_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_s3_bucket_policy" "artifacts" {
  count = local.create_artifact_bucket ? 1 : 0

  bucket = aws_s3_bucket.artifacts[0].id
  policy = data.aws_iam_policy_document.artifacts_bucket[0].json
}

data "aws_iam_policy_document" "artifacts_bucket" {
  count = local.create_artifact_bucket ? 1 : 0

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.artifacts[0].arn,
      "${aws_s3_bucket.artifacts[0].arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}
