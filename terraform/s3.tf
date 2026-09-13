resource "aws_s3_bucket" "lambda_artifacts" {
  bucket = var.lambda_s3_bucket

  tags = {
    Name        = var.lambda_s3_bucket
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

data "archive_file" "lambda_placeholder" {
  type        = "zip"
  output_path = "${path.module}/placeholder.zip"

  source {
    content  = "exports.handler = async () => ({ statusCode: 200, body: 'Placeholder - deploy via tech-challenge-serverless CI/CD' });"
    filename = "handler.js"
  }
}

resource "aws_s3_object" "lambda_placeholder" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  key    = var.lambda_s3_key
  source = data.archive_file.lambda_placeholder.output_path
  etag   = data.archive_file.lambda_placeholder.output_md5

  lifecycle {
    ignore_changes = [source, etag]
  }
}
