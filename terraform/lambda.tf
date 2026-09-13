resource "aws_lambda_function" "auth_cpf" {
  function_name = "${var.project_name}-${var.environment}-auth-cpf"
  description   = "Autenticacao de clientes por CPF"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler.handler"
  runtime       = "nodejs20.x"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  s3_bucket = var.lambda_s3_bucket
  s3_key    = var.lambda_s3_key

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_SECRET_ARN = var.db_secret_arn
      JWT_SECRET    = var.jwt_secret
      NODE_ENV      = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.lambda_auth,
    aws_s3_object.lambda_placeholder
  ]
}

resource "aws_cloudwatch_log_group" "lambda_auth" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-auth-cpf"
  retention_in_days = 14
}

resource "aws_lambda_function" "notificacao" {
  function_name = "${var.project_name}-${var.environment}-notificacao"
  description   = "Notificacao de status de OS por e-mail"
  role          = aws_iam_role.lambda_execution.arn
  handler       = "handler.handler"
  runtime       = "nodejs20.x"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory_size

  s3_bucket = var.lambda_s3_bucket
  s3_key    = "lambda-notificacao/placeholder.zip"

  environment {
    variables = {
      NODE_ENV = var.environment
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_cloudwatch_log_group.lambda_notificacao
  ]
}

resource "aws_cloudwatch_log_group" "lambda_notificacao" {
  name              = "/aws/lambda/${var.project_name}-${var.environment}-notificacao"
  retention_in_days = 14
}
