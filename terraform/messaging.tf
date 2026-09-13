resource "aws_sns_topic" "notificacao_status" {
  name = "${var.project_name}-${var.environment}-notificacao-status"

  tags = {
    Name = "${var.project_name}-${var.environment}-notificacao-status"
  }
}

resource "aws_sqs_queue" "notificacao_status_dlq" {
  name                      = "${var.project_name}-${var.environment}-notificacao-status-dlq"
  message_retention_seconds = 1209600

  tags = {
    Name = "${var.project_name}-${var.environment}-notificacao-status-dlq"
  }
}

resource "aws_sqs_queue" "notificacao_status" {
  name                       = "${var.project_name}-${var.environment}-notificacao-status"
  visibility_timeout_seconds = var.lambda_timeout * 6
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 10

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.notificacao_status_dlq.arn
    maxReceiveCount     = var.sqs_notificacao_max_receive_count
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-notificacao-status"
  }
}

resource "aws_sqs_queue_policy" "notificacao_status" {
  queue_url = aws_sqs_queue.notificacao_status.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSnsPublish"
        Effect    = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.notificacao_status.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.notificacao_status.arn
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "notificacao_status" {
  topic_arn = aws_sns_topic.notificacao_status.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notificacao_status.arn
}

resource "aws_sns_topic_policy" "notificacao_status" {
  arn = aws_sns_topic.notificacao_status.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowApiPublish"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.api_notificacao_irsa.arn }
        Action    = "sns:Publish"
        Resource  = aws_sns_topic.notificacao_status.arn
      }
    ]
  })
}
