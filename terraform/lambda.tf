resource "aws_lambda_function" "auth_cpf" {
  function_name                  = "${var.project_name}-${var.environment}-auth-cpf"
  description                    = "Autenticacao de clientes por CPF"
  role                           = aws_iam_role.lambda_execution.arn
  handler                        = "handler.handler"
  runtime                        = "nodejs20.x"
  timeout                        = var.lambda_timeout
  memory_size                    = var.lambda_memory_size
  reserved_concurrent_executions = var.lambda_auth_reserved_concurrency

  s3_bucket = var.lambda_s3_bucket
  s3_key    = var.lambda_s3_key

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda.id]
  }

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      DB_SECRET_ARN           = var.db_secret_arn
      JWT_SECRET_ARN          = aws_secretsmanager_secret.jwt.arn
      JWT_ISSUER              = var.jwt_issuer
      JWT_AUDIENCE            = var.jwt_audience
      AUTH_RATE_LIMIT_TABLE   = aws_dynamodb_table.auth_cpf_rate_limit.name
      AUTH_CPF_MAX_ATTEMPTS   = tostring(var.auth_cpf_max_attempts)
      AUTH_CPF_WINDOW_SECONDS = tostring(var.auth_cpf_window_seconds)
      AUTH_RESPONSE_TARGET_MS = tostring(var.auth_response_target_ms)
      NODE_ENV                = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_xray,
    aws_cloudwatch_log_group.lambda_auth,
    aws_s3_object.lambda_placeholder
  ]
}

# CloudWatch Logs ja criptografa em repouso com chave AWS; CMK nao exigida.
#tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "lambda_auth" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-auth-cpf"
  retention_in_days = 14
}

resource "aws_lambda_function" "notificacao" {
  function_name                  = "${var.project_name}-${var.environment}-notificacao"
  description                    = "Notificacao de status de OS por e-mail"
  role                           = aws_iam_role.lambda_notificacao_execution.arn
  handler                        = "handler.handler"
  runtime                        = "nodejs20.x"
  timeout                        = var.lambda_timeout
  memory_size                    = var.lambda_memory_size
  reserved_concurrent_executions = var.lambda_notificacao_reserved_concurrency

  s3_bucket = var.lambda_s3_bucket
  s3_key    = "lambda-notificacao/placeholder.zip"

  environment {
    variables = {
      NODE_ENV            = var.environment
      SENDGRID_SECRET_ARN = aws_secretsmanager_secret.sendgrid_api_key.arn
      SENDGRID_FROM_EMAIL = var.sendgrid_from_email
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_notificacao_basic,
    aws_iam_role_policy_attachment.lambda_notificacao_xray,
    aws_cloudwatch_log_group.lambda_notificacao,
    aws_s3_object.lambda_notificacao_placeholder
  ]
}

resource "aws_lambda_event_source_mapping" "notificacao_sqs" {
  event_source_arn = aws_sqs_queue.notificacao_status.arn
  function_name    = aws_lambda_function.notificacao.arn
  batch_size       = var.sqs_notificacao_batch_size
  enabled          = true

  function_response_types = ["ReportBatchItemFailures"]
}

#tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "lambda_notificacao" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-notificacao"
  retention_in_days = 14
}
