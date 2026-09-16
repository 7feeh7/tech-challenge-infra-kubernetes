locals {
  dd_monitor_tags = [
    "env:${var.environment}",
    "service:${local.dd_service}",
    "team:tech-challenge",
  ]
}

resource "datadog_monitor" "os_transicao_falha" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Falha no processamento de OS"
  type    = "query alert"
  message = <<-EOT
    Falhas de transicao de OS acima do limiar.

    Runbook: https://github.com/fiap-tech-challenge/tech-challenge/blob/develop/docs/runbook-correlacao.md

    Correlacao: busque `@correlationId` nos logs e traces de `service:${local.dd_service}`.

    ${var.datadog_alert_recipients}
  EOT

  query = "sum(last_10m):sum:oficina.ordem_servico.transicao_falha{environment:${var.environment}}.as_count() > 3"

  monitor_thresholds {
    critical = 3
    warning  = 1
  }

  notify_no_data    = false
  renotify_interval = 60
  include_tags      = true
  tags              = local.dd_monitor_tags
}

resource "datadog_monitor" "http_error_rate" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Taxa de erro HTTP"
  type    = "query alert"
  message = <<-EOT
    Taxa de erros HTTP acima de 5% nos ultimos 5 minutos.

    ${var.datadog_alert_recipients}
  EOT

  query = "sum(last_5m):sum:trace.fastify.request.errors{service:${local.dd_service},env:${var.environment}}.as_count() / clamp_min(sum:trace.fastify.request.hits{service:${local.dd_service},env:${var.environment}}.as_count(), 1) * 100 > 5"

  monitor_thresholds {
    critical = 5
    warning  = 2
  }

  notify_no_data    = false
  renotify_interval = 60
  include_tags      = true
  tags              = local.dd_monitor_tags
}

resource "datadog_monitor" "http_latency_p95" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Latencia P95 HTTP"
  type    = "query alert"
  message = <<-EOT
    Latencia P95 acima de 2 segundos.

    ${var.datadog_alert_recipients}
  EOT

  query = "avg(last_5m):p95:trace.fastify.request{service:${local.dd_service},env:${var.environment}} > 2"

  monitor_thresholds {
    critical = 2
    warning  = 1
  }

  notify_no_data    = false
  renotify_interval = 60
  include_tags      = true
  tags              = local.dd_monitor_tags
}

resource "datadog_monitor" "apm_no_data" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Ausencia de traces APM"
  type    = "query alert"
  message = <<-EOT
    Nenhum trace recebido da API nos ultimos 15 minutos.

    ${var.datadog_alert_recipients}
  EOT

  query = "sum(last_15m):sum:trace.fastify.request.hits{service:${local.dd_service},env:${var.environment}}.as_count() < 1"

  monitor_thresholds {
    critical = 1
  }

  notify_no_data    = true
  no_data_timeframe = 15
  renotify_interval = 30
  include_tags      = true
  tags              = local.dd_monitor_tags
}

resource "datadog_monitor" "pod_restarts" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Pods reiniciando"
  type    = "query alert"
  message = <<-EOT
    Pods da API reiniciando com frequencia.

    ${var.datadog_alert_recipients}
  EOT

  query = "sum(last_10m):sum:kubernetes.containers.restarts{kube_deployment:oficina-api,kube_namespace:oficina}.as_count() > 3"

  monitor_thresholds {
    critical = 3
    warning  = 1
  }

  notify_no_data    = false
  renotify_interval = 30
  include_tags      = true
  tags              = local.dd_monitor_tags
}

resource "datadog_monitor" "pods_unavailable" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Pods indisponiveis"
  type    = "query alert"
  message = <<-EOT
    Nenhum pod running para a API.

    ${var.datadog_alert_recipients}
  EOT

  query = "avg(last_5m):sum:kubernetes.pods.running{kube_deployment:oficina-api,kube_namespace:oficina} < 1"

  monitor_thresholds {
    critical = 1
  }

  notify_no_data    = true
  no_data_timeframe = 10
  renotify_interval = 15
  include_tags      = true
  tags              = local.dd_monitor_tags
}

resource "datadog_monitor" "high_cpu" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] CPU alta"
  type    = "query alert"
  message = <<-EOT
    CPU acima de 80% por 5 minutos.

    ${var.datadog_alert_recipients}
  EOT

  # usage.total e nanocore; limits e core. Sem /1e9 o percentual fica na casa dos milhoes e o alerta dispara em idle.
  query = "avg(last_5m):(avg:kubernetes.cpu.usage.total{kube_deployment:oficina-api,kube_namespace:oficina} / 1000000000) / avg:kubernetes.cpu.limits{kube_deployment:oficina-api,kube_namespace:oficina} * 100 > 80"

  monitor_thresholds {
    critical = 80
    warning  = 60
  }

  notify_no_data    = false
  renotify_interval = 30
  include_tags      = true
  tags              = local.dd_monitor_tags
}

resource "datadog_monitor" "high_memory" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Memoria alta"
  type    = "query alert"
  message = <<-EOT
    Memoria acima de 80% do limite por 5 minutos.

    ${var.datadog_alert_recipients}
  EOT

  query = "avg(last_5m):avg:kubernetes.memory.usage{kube_deployment:oficina-api,kube_namespace:oficina} / avg:kubernetes.memory.limits{kube_deployment:oficina-api,kube_namespace:oficina} * 100 > 80"

  monitor_thresholds {
    critical = 80
    warning  = 70
  }

  notify_no_data    = false
  renotify_interval = 30
  include_tags      = true
  tags              = local.dd_monitor_tags
}

resource "datadog_monitor" "lambda_notificacao_errors" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Erros Lambda notificacao"
  type    = "query alert"
  message = <<-EOT
    Erros na Function de notificacao.

    ${var.datadog_alert_recipients}
  EOT

  query = "sum(last_5m):sum:aws.lambda.errors{functionname:${var.project_name}-${var.environment}-notificacao}.as_count() > 0"

  monitor_thresholds {
    critical = 0
  }

  notify_no_data    = false
  renotify_interval = 30
  include_tags      = true
  tags              = local.dd_monitor_tags
}

resource "datadog_monitor" "sqs_backlog" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Backlog SQS notificacao"
  type    = "query alert"
  message = <<-EOT
    Backlog da fila de notificacao acima do limiar.

    ${var.datadog_alert_recipients}
  EOT

  query = "avg(last_5m):avg:aws.sqs.approximate_number_of_messages_visible{queuename:${var.project_name}-${var.environment}-notificacao-status} > ${var.alarm_sqs_backlog_count}"

  monitor_thresholds {
    critical = var.alarm_sqs_backlog_count
    warning  = floor(var.alarm_sqs_backlog_count * 0.5)
  }

  notify_no_data    = false
  renotify_interval = 30
  include_tags      = true
  tags              = local.dd_monitor_tags
}

resource "datadog_monitor" "sqs_age" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Idade SQS notificacao"
  type    = "query alert"
  message = <<-EOT
    Mensagem mais antiga na fila excedeu o limiar.

    ${var.datadog_alert_recipients}
  EOT

  query = "avg(last_5m):avg:aws.sqs.approximate_age_of_oldest_message{queuename:${var.project_name}-${var.environment}-notificacao-status} > ${var.alarm_sqs_age_seconds}"

  monitor_thresholds {
    critical = var.alarm_sqs_age_seconds
    warning  = floor(var.alarm_sqs_age_seconds * 0.5)
  }

  notify_no_data    = false
  renotify_interval = 30
  include_tags      = true
  tags              = local.dd_monitor_tags
}

resource "datadog_monitor" "sqs_dlq" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Mensagens na DLQ"
  type    = "query alert"
  message = <<-EOT
    Mensagens visiveis na DLQ de notificacao.

    ${var.datadog_alert_recipients}
  EOT

  query = "avg(last_5m):avg:aws.sqs.approximate_number_of_messages_visible{queuename:${var.project_name}-${var.environment}-notificacao-status-dlq} > 0"

  monitor_thresholds {
    critical = 0
  }

  notify_no_data    = false
  renotify_interval = 15
  include_tags      = true
  tags              = local.dd_monitor_tags
}

resource "datadog_monitor" "integracao_falha" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Falhas de integracao"
  type    = "query alert"
  message = <<-EOT
    Falhas em integracoes externas (PostgreSQL, SNS, SendGrid, etc.).

    ${var.datadog_alert_recipients}
  EOT

  query = "sum(last_10m):sum:oficina.integracao.falha{environment:${var.environment}} by {integration}.as_count() > 5"

  monitor_thresholds {
    critical = 5
    warning  = 2
  }

  notify_no_data    = false
  renotify_interval = 30
  include_tags      = true
  tags              = local.dd_monitor_tags
}
