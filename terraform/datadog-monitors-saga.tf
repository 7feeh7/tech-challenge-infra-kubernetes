# Monitores da Saga da OS (E35). Falha tecnica (outbox, consumo, SQS, Mercado Pago) fica separada do
# resultado de negocio: nenhum monitor aqui conta recusa de pagamento, 4xx do Mercado Pago ou OS cancelada.
# Limites por variavel em variables.tf (alarm_*); roteiro de verificacao em docs/observabilidade.md.

locals {
  # Os sinais do Billing vem de metricas de log (datadog-logs.tf), sem a tag environment: o log do Billing
  # leva NODE_ENV em "environment", que nao e o ambiente do Terraform. Hoje so existe o ambiente producao (001-R1).
  sinais_situacao_financeira_indeterminada = {
    os = {
      descricao = "OS"
      query     = "sum(last_30m):sum:oficina.situacao_financeira.indeterminada{environment:${var.environment}}.as_count() > ${var.alarm_situacao_financeira_indeterminada_count}"
      acao      = "A consulta financeira ficou sem resposta conclusiva. Reprocesse pelo POST /v1/ordens-servico/{id}/consulta-financeira depois de confirmar o Billing (D4.10)."
    }
    billing_situacao = {
      descricao = "Billing situacao"
      query     = "sum(last_30m):sum:billing.situacao_financeira_indeterminada{*}.as_count() > ${var.alarm_situacao_financeira_indeterminada_count}"
      acao      = "O Billing registrou pendencia de monitoramento de situacao financeira. Busque `service:billing-api @metric:billing.situacao_financeira_indeterminada` nos logs."
    }
    billing_pendencia_estorno = {
      descricao = "Billing pendencia de estorno"
      query     = "sum(last_30m):sum:billing.pendencia_estorno_aberta{*}.as_count() > ${var.alarm_situacao_financeira_indeterminada_count}"
      acao      = "Pendencia manual de estorno aberta: confira no Mercado Pago e resolva manualmente. Busque `service:billing-api @metric:billing.pendencia_estorno_aberta` nos logs."
    }
    billing_operacao = {
      descricao = "Billing operacao financeira"
      query     = "sum(last_30m):sum:billing.operacao_financeira_indeterminada{*}.as_count() > ${var.alarm_situacao_financeira_indeterminada_count}"
      acao      = "Operacao de cancelamento financeiro esgotou as tentativas com resultado indeterminado. Busque `service:billing-api @metric:billing.operacao_financeira_indeterminada` nos logs."
    }
  }
}

resource "datadog_monitor" "os_outbox_atrasada" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Outbox atrasada OS"
  type    = "query alert"
  message = <<-EOT
    A mensagem pendente mais antiga da outbox do OS passou do limiar. Falha tecnica: publicador parado,
    SQS indisponivel ou mensagem que falha sempre. Veja `oficina.outbox.publicacao_falha` e os logs do OS.

    ${var.datadog_alert_recipients}
  EOT

  query = "max(last_5m):max:oficina.outbox.idade_mais_antiga_segundos{environment:${var.environment}} > ${var.alarm_outbox_idade_segundos}"

  monitor_thresholds {
    critical = var.alarm_outbox_idade_segundos
    warning  = floor(var.alarm_outbox_idade_segundos * 0.5)
  }

  # O gauge so e emitido com o publicador ligado; sem dado e esperado enquanto ele estiver desligado.
  notify_no_data    = false
  renotify_interval = 30
  include_tags      = true
  tags              = concat(local.dd_monitor_tags, ["servico:os"])
}

resource "datadog_monitor" "os_outbox_publicacao_falha" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Falhas de publicacao da outbox OS"
  type    = "query alert"
  message = <<-EOT
    Falhas repetidas ao publicar mensagens da outbox do OS. A espera progressiva reenvia a mensagem,
    mas falha sempre indica fila, permissao ou envelope com problema.

    ${var.datadog_alert_recipients}
  EOT

  query = "sum(last_10m):sum:oficina.outbox.publicacao_falha{environment:${var.environment}}.as_count() > ${var.alarm_outbox_publicacao_falha_count}"

  monitor_thresholds {
    critical = var.alarm_outbox_publicacao_falha_count
    warning  = floor(var.alarm_outbox_publicacao_falha_count * 0.5)
  }

  notify_no_data    = false
  renotify_interval = 30
  include_tags      = true
  tags              = concat(local.dd_monitor_tags, ["servico:os"])
}

resource "datadog_monitor" "os_consumo_erro_transitorio" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Erros transitorios de consumo OS"
  type    = "query alert"
  message = <<-EOT
    Erros transitorios ao consumir mensagens na fila do OS acima do limiar. A mensagem volta para a fila
    e e reprocessada; erro persistente leva a mensagem para a DLQ.

    ${var.datadog_alert_recipients}
  EOT

  query = "sum(last_10m):sum:oficina.mensagem.erro_consumo{environment:${var.environment},tipo:transitorio}.as_count() > ${var.alarm_consumo_erro_transitorio_count}"

  monitor_thresholds {
    critical = var.alarm_consumo_erro_transitorio_count
    warning  = floor(var.alarm_consumo_erro_transitorio_count * 0.5)
  }

  notify_no_data    = false
  renotify_interval = 30
  include_tags      = true
  tags              = concat(local.dd_monitor_tags, ["servico:os"])
}

resource "datadog_monitor" "os_consumo_erro_permanente" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Erros permanentes de consumo OS"
  type    = "query alert"
  message = <<-EOT
    Erro permanente ao consumir mensagem no OS (envelope invalido, conteudo divergente ou tipo sem processador).
    A mensagem vai direto para a DLQ `os-in-dlq` e nao melhora com nova tentativa.

    Correlacao: busque `@correlationId` nos logs de `service:${local.dd_service}`.

    ${var.datadog_alert_recipients}
  EOT

  query = "sum(last_10m):sum:oficina.mensagem.erro_consumo{environment:${var.environment},tipo:permanente}.as_count() > ${var.alarm_consumo_erro_permanente_count}"

  monitor_thresholds {
    critical = var.alarm_consumo_erro_permanente_count
  }

  notify_no_data    = false
  renotify_interval = 30
  include_tags      = true
  tags              = concat(local.dd_monitor_tags, ["servico:os"])
}

# Um monitor por status porque cada estado tem o seu limite. A consulta do gauge pode falhar sem emitir valor
# (o ciclo e descartado), entao a ausencia de dado tambem alerta.
resource "datadog_monitor" "os_parada" {
  for_each = local.datadog_habilitado ? tomap(var.alarm_os_parada_segundos) : {}

  name    = "[Tech Challenge] OS parada em ${each.key}"
  type    = "query alert"
  message = <<-EOT
    {{#is_alert}}
    Ha OS parada em ${each.key} por mais de ${each.value} segundos.
    {{/is_alert}}
    {{#is_no_data}}
    Sem o gauge `oficina.ordem_servico.idade_mais_antiga_segundos` do status ${each.key}. Confira
    `OS_IDADE_POR_STATUS_HABILITADO=true`, se o OS esta no ar e se a consulta de idade esta falhando.
    {{/is_no_data}}

    ${var.datadog_alert_recipients}
  EOT

  query = "max(last_5m):max:oficina.ordem_servico.idade_mais_antiga_segundos{environment:${var.environment},status:${each.key}} > ${each.value}"

  monitor_thresholds {
    critical = each.value
  }

  notify_no_data    = true
  no_data_timeframe = var.alarm_os_parada_sem_dado_minutos
  renotify_interval = 60
  include_tags      = true
  tags              = concat(local.dd_monitor_tags, ["servico:os", "status:${each.key}"])
}

resource "datadog_monitor" "situacao_financeira_indeterminada" {
  for_each = local.datadog_habilitado ? local.sinais_situacao_financeira_indeterminada : {}

  name    = "[Tech Challenge] Situacao financeira indeterminada ${each.value.descricao}"
  type    = "query alert"
  message = <<-EOT
    Situacao financeira indeterminada (${each.value.descricao}). ${each.value.acao}

    ${var.datadog_alert_recipients}
  EOT

  query = each.value.query

  monitor_thresholds {
    critical = var.alarm_situacao_financeira_indeterminada_count
  }

  # Contador de evento: ausencia de dado significa que nao houve ocorrencia.
  notify_no_data    = false
  renotify_interval = 60
  include_tags      = true
  tags              = concat(local.dd_monitor_tags, ["servico:financeiro"])
}

resource "datadog_monitor" "mercado_pago_falha_tecnica" {
  count = var.datadog_app_key != "" ? 1 : 0

  name    = "[Tech Challenge] Falha tecnica no Mercado Pago"
  type    = "query alert"
  message = <<-EOT
    Falhas tecnicas nas chamadas do Billing ao Mercado Pago (timeout, rede, HTTP 5xx, resposta invalida
    ou token ausente). Recusa de pagamento e 4xx nao entram nesta contagem.

    Detalhe por `operacao` e `motivo` no dashboard "Saga da OS".

    ${var.datadog_alert_recipients}
  EOT

  query = "sum(last_10m):sum:billing.mercado_pago.falha_tecnica{*}.as_count() > ${var.alarm_mercado_pago_falha_tecnica_count}"

  monitor_thresholds {
    critical = var.alarm_mercado_pago_falha_tecnica_count
    warning  = floor(var.alarm_mercado_pago_falha_tecnica_count * 0.5)
  }

  notify_no_data    = false
  renotify_interval = 30
  include_tags      = true
  tags              = concat(local.dd_monitor_tags, ["servico:billing"])
}
