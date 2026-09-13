resource "random_id" "sendgrid_suffix" {
  byte_length = 4
}

resource "aws_secretsmanager_secret" "sendgrid_api_key" {
  name = "${var.project_name}/${var.environment}/sendgrid-api-key-${random_id.sendgrid_suffix.hex}"

  tags = {
    Name = "${var.project_name}-${var.environment}-sendgrid-api-key"
  }
}

resource "aws_secretsmanager_secret_version" "sendgrid_api_key" {
  secret_id = aws_secretsmanager_secret.sendgrid_api_key.id
  secret_string = jsonencode({
    apiKey = var.sendgrid_api_key
  })
}
