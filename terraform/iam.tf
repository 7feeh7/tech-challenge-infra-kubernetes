resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_xray" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

data "aws_caller_identity" "current" {}

# Wildcard apenas enquanto db_secret_arn nao existe (secret criado pelo repo
# infra-database depois). Restrito a conta atual e ao prefixo do projeto.
#tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_role" "lambda_notificacao_execution" {
  name = "${var.project_name}-${var.environment}-lambda-notificacao-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_notificacao_basic" {
  role       = aws_iam_role.lambda_notificacao_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_notificacao_xray" {
  role       = aws_iam_role.lambda_notificacao_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy" "lambda_notificacao_sqs" {
  name = "${var.project_name}-${var.environment}-lambda-notificacao-sqs"
  role = aws_iam_role.lambda_notificacao_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [
          aws_sqs_queue.notificacao_status.arn,
          aws_sqs_queue.notificacao_status_dlq.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_notificacao_sendgrid_secret" {
  name = "${var.project_name}-${var.environment}-lambda-notificacao-sendgrid"
  role = aws_iam_role.lambda_notificacao_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [aws_secretsmanager_secret.sendgrid_api_key.arn]
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_secrets" {
  name = "${var.project_name}-${var.environment}-lambda-secrets"
  role = aws_iam_role.lambda_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = compact([
          var.db_secret_arn != "" ? var.db_secret_arn : "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/*",
          aws_secretsmanager_secret.jwt.arn,
        ])
      }
    ]
  })
}
