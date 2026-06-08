data "aws_caller_identity" "current" {}

# ---------------------------------------------------------------------------
# Tempo trace storage
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "tempo_traces" {
  bucket = "tempo-traces-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "tempo_traces" {
  bucket = aws_s3_bucket.tempo_traces.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "tempo_traces" {
  bucket = aws_s3_bucket.tempo_traces.id

  rule {
    id     = "expire-traces"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tempo_traces" {
  bucket = aws_s3_bucket.tempo_traces.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tempo_traces" {
  bucket                  = aws_s3_bucket.tempo_traces.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# Frontend static assets
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "frontend_assets" {
  bucket = "frontend-assets-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "frontend_assets" {
  bucket = aws_s3_bucket.frontend_assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_assets" {
  bucket = aws_s3_bucket.frontend_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_assets" {
  bucket                  = aws_s3_bucket.frontend_assets.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
