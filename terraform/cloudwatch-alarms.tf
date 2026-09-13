resource "aws_cloudwatch_metric_alarm" "sqs_notificacao_age" {
  alarm_name          = "${var.project_name}-${var.environment}-sqs-notificacao-age"
  alarm_description   = "Idade da mensagem mais antiga na fila de notificacao"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateAgeOfOldestMessage"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.alarm_sqs_age_seconds
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.notificacao_status.name
  }
}

resource "aws_cloudwatch_metric_alarm" "sqs_notificacao_backlog" {
  alarm_name          = "${var.project_name}-${var.environment}-sqs-notificacao-backlog"
  alarm_description   = "Volume visivel na fila de notificacao"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = var.alarm_sqs_backlog_count
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.notificacao_status.name
  }
}

resource "aws_cloudwatch_metric_alarm" "sqs_notificacao_dlq" {
  alarm_name          = "${var.project_name}-${var.environment}-sqs-notificacao-dlq"
  alarm_description   = "Mensagens na DLQ de notificacao"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.notificacao_status_dlq.name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_notificacao_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-lambda-notificacao-errors"
  alarm_description   = "Erros na Lambda de notificacao"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.notificacao.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_notificacao_throttles" {
  alarm_name          = "${var.project_name}-${var.environment}-lambda-notificacao-throttles"
  alarm_description   = "Throttles na Lambda de notificacao"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.notificacao.function_name
  }
}
