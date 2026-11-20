# Metricas geradas a partir dos logs JSON do Billing (D7.3). O Billing nao tem APM nem biblioteca de metricas:
# o sinal e uma linha de log com o campo `metric` (tech-challenge-billing, docs/metricas-de-log.md).

locals {
  # Dimensoes de agrupamento por metrica, sempre de baixa cardinalidade. Nunca ordemServicoId, correlationId,
  # operacaoId ou cobrancaId (D7.1). O motivo de situacao_financeira_indeterminada pode ser texto livre do erro
  # do gateway, por isso essa metrica nao agrupa por motivo.
  metricas_log_billing = {
    "billing.situacao_financeira_indeterminada" = []
    "billing.operacao_financeira_indeterminada" = []
    "billing.pendencia_estorno_aberta"          = ["motivo"]
    "billing.mercado_pago.falha_tecnica"        = ["operacao", "motivo"]
  }
}

# O JsonLoggerService do Billing grava o JSON do sinal como texto dentro do atributo `message`, e o Datadog
# so extrai atributos do JSON de nivel raiz. Sem este parser, `@metric`, `@operacao` e `@motivo` nao existem.
resource "datadog_logs_custom_pipeline" "billing_json_message" {
  count = var.datadog_app_key != "" ? 1 : 0

  name       = "Billing - JSON do message"
  is_enabled = true

  filter {
    query = "service:billing-api"
  }

  processor {
    grok_parser {
      name       = "Extrai o JSON do message para atributos"
      is_enabled = true
      source     = "message"
      samples = [
        jsonencode({
          metric     = "billing.mercado_pago.falha_tecnica"
          operacao   = "criar_order"
          motivo     = "http_5xx"
          statusHttp = 503
        }),
      ]

      grok {
        # %%{ e o escape do Terraform para o literal %{ do Grok.
        support_rules = ""
        match_rules   = "extrai_json_do_message %%{data::json}"
      }
    }
  }
}

resource "datadog_logs_metric" "billing" {
  for_each = local.datadog_habilitado ? tomap(local.metricas_log_billing) : {}

  name = each.key

  compute {
    aggregation_type = "count"
  }

  filter {
    query = "service:billing-api @metric:${each.key}"
  }

  dynamic "group_by" {
    for_each = each.value

    content {
      path     = "@${group_by.value}"
      tag_name = group_by.value
    }
  }

  # A metrica so enxerga atributos depois do pipeline de logs.
  depends_on = [datadog_logs_custom_pipeline.billing_json_message]
}
