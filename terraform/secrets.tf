resource "random_id" "resend_suffix" {
  byte_length = 4
}

resource "random_id" "jwt_suffix" {
  byte_length = 4
}

resource "random_id" "jwt_public_suffix" {
  byte_length = 4
}

resource "random_id" "token_billing_os_suffix" {
  byte_length = 4
}

resource "random_id" "token_execution_os_suffix" {
  byte_length = 4
}

resource "random_id" "token_auth_cpf_os_suffix" {
  byte_length = 4
}

# Conteineres vazios: valores gravados pelo autor no runbook (passo 4.1), fora do Terraform.
#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "jwt_private" {
  name = "${var.project_name}/${var.environment}/jwt-private-${random_id.jwt_suffix.hex}"

  tags = {
    Name         = "${var.project_name}-${var.environment}-jwt-private"
    Finalidade   = "jwt-rs256-private"
    Algoritmo    = "RS256"
    Consumidores = "oficina auth-cpf"
  }
}

#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "jwt_public" {
  name = "${var.project_name}/${var.environment}/jwt-public-${random_id.jwt_public_suffix.hex}"

  tags = {
    Name         = "${var.project_name}-${var.environment}-jwt-public"
    Finalidade   = "jwt-rs256-public"
    Algoritmo    = "RS256"
    Consumidores = "oficina billing execution"
  }
}

#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "token_billing_os" {
  name = "${var.project_name}/${var.environment}/token-billing-os-${random_id.token_billing_os_suffix.hex}"

  tags = {
    Name         = "${var.project_name}-${var.environment}-token-billing-os"
    Relacao      = "billing-os"
    Consumidores = "billing oficina"
  }
}

#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "token_execution_os" {
  name = "${var.project_name}/${var.environment}/token-execution-os-${random_id.token_execution_os_suffix.hex}"

  tags = {
    Name         = "${var.project_name}-${var.environment}-token-execution-os"
    Relacao      = "execution-os"
    Consumidores = "execution oficina"
  }
}

#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "token_auth_cpf_os" {
  name = "${var.project_name}/${var.environment}/token-auth-cpf-os-${random_id.token_auth_cpf_os_suffix.hex}"

  tags = {
    Name         = "${var.project_name}-${var.environment}-token-auth-cpf-os"
    Relacao      = "auth-cpf-os"
    Consumidores = "auth-cpf oficina"
  }
}

# Secrets Manager usa chave gerenciada AWS por padrao; CMK customizado fora do escopo por custo.
#tfsec:ignore:aws-ssm-secret-use-customer-key
resource "aws_secretsmanager_secret" "resend_api_key" {
  name = "${var.project_name}/${var.environment}/resend-api-key-${random_id.resend_suffix.hex}"

  tags = {
    Name = "${var.project_name}-${var.environment}-resend-api-key"
  }
}

resource "aws_secretsmanager_secret_version" "resend_api_key" {
  secret_id = aws_secretsmanager_secret.resend_api_key.id
  secret_string = jsonencode({
    apiKey = var.resend_api_key
  })
}