resource "aws_dynamodb_table" "auth_cpf_rate_limit" {
  name         = "${var.project_name}-${var.environment}-auth-cpf-rate"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "cpfHash"

  attribute {
    name = "cpfHash"
    type = "S"
  }

  ttl {
    attribute_name = "expiresAt"
    enabled        = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-auth-cpf-rate"
  }
}

resource "aws_iam_role_policy" "lambda_auth_rate_limit" {
  name = "${var.project_name}-${var.environment}-lambda-auth-rate"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
        ]
        Resource = aws_dynamodb_table.auth_cpf_rate_limit.arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_metric_filter" "auth_cpf_failures" {
  name           = "${var.project_name}-${var.environment}-auth-cpf-failures"
  log_group_name = aws_cloudwatch_log_group.lambda_auth.name
  pattern        = "{ $.evento = \"auth_cpf_metrica\" && $.metric = \"auth.cpf.failures\" }"

  metric_transformation {
    name          = "AuthCpfFailures"
    namespace     = "TechChallenge/Auth"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "auth_cpf_failures_anomaly" {
  alarm_name          = "${var.project_name}-${var.environment}-auth-cpf-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "AuthCpfFailures"
  namespace           = "TechChallenge/Auth"
  period              = 300
  statistic           = "Sum"
  threshold           = var.auth_failure_alarm_threshold
  alarm_description   = "Volume anormal de falhas em POST /auth/cpf (CPF mascarado nos logs; IP agregado por prefixo /16)."
  treat_missing_data  = "notBreaching"

  tags = {
    Name = "${var.project_name}-${var.environment}-auth-cpf-failures"
  }
}
