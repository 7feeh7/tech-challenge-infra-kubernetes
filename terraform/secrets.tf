resource "random_id" "sendgrid_suffix" {
  byte_length = 4
}

resource "random_id" "jwt_suffix" {
  byte_length = 4
}

# Secrets Manager usa chave gerenciada AWS por padrao; CMK customizado fora do escopo por custo.
#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "jwt" {
  name = "${var.project_name}/${var.environment}/jwt-secret-${random_id.jwt_suffix.hex}"

  tags = {
    Name = "${var.project_name}-${var.environment}-jwt-secret"
  }
}

resource "aws_secretsmanager_secret_version" "jwt" {
  secret_id = aws_secretsmanager_secret.jwt.id
  secret_string = jsonencode({
    secret = var.jwt_secret
  })
}

# Secrets Manager usa chave gerenciada AWS por padrao; CMK customizado fora do escopo por custo.
#tfsec:ignore:aws-ssm-secret-use-customer-key
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
