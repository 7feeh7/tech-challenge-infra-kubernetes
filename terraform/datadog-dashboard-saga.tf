resource "datadog_dashboard" "saga_os" {
  count = var.datadog_app_key != "" ? 1 : 0

  title       = "Tech Challenge - Saga da OS"
  description = "Fluxo por status, outbox, consumo, DLQs, situacao financeira indeterminada e falhas tecnicas do Mercado Pago."
  layout_type = "ordered"

  template_variable {
    name    = "env"
    prefix  = "environment"
    default = var.environment
  }

  widget {
    group_definition {
      title       = "Fluxo por status"
      layout_type = "ordered"

      widget {
        timeseries_definition {
          title = "OS criadas por dia"
          request {
            q            = "sum:oficina.ordem_servico.criada{$env}.rollup(sum, 86400)"
            display_type = "bars"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Idade da OS mais antiga por status (s)"
          request {
            q            = "max:oficina.ordem_servico.idade_mais_antiga_segundos{$env} by {status}"
            display_type = "line"
          }
        }
      }

      widget {
        toplist_definition {
          title = "Tempo medio por status, na saida do status (s)"
          request {
            q = "avg:oficina.ordem_servico.tempo_por_status{$env} by {status}"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Falhas de transicao de OS"
          request {
            q            = "sum:oficina.ordem_servico.transicao_falha{$env}.as_count()"
            display_type = "bars"
          }
        }
      }
    }
  }

  widget {
    group_definition {
      title       = "Outbox do OS"
      layout_type = "ordered"

      widget {
        timeseries_definition {
          title = "Mensagens pendentes"
          request {
            q            = "max:oficina.outbox.pendentes{$env}"
            display_type = "line"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Idade da mensagem mais antiga pendente (s)"
          request {
            q            = "max:oficina.outbox.idade_mais_antiga_segundos{$env}"
            display_type = "line"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Falhas de publicacao"
          request {
            q            = "sum:oficina.outbox.publicacao_falha{$env}.as_count()"
            display_type = "bars"
          }
        }
      }
    }
  }

  widget {
    group_definition {
      title       = "Consumo de mensagens do OS"
      layout_type = "ordered"

      widget {
        timeseries_definition {
          title = "Processadas e duplicadas"
          request {
            q            = "sum:oficina.mensagem.processada{$env} by {resultado}.as_count()"
            display_type = "bars"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Erros de consumo por tipo"
          request {
            q            = "sum:oficina.mensagem.erro_consumo{$env} by {tipo}.as_count()"
            display_type = "bars"
          }
        }
      }
    }
  }

  widget {
    group_definition {
      title       = "Filas e DLQs por servico"
      layout_type = "ordered"

      widget {
        timeseries_definition {
          title = "Mensagens nas DLQs"
          dynamic "request" {
            for_each = local.filas_monitoradas

            content {
              q            = "max:aws.sqs.approximate_number_of_messages_visible{queuename:${request.value.dlq}}"
              display_type = "bars"

              metadata {
                expression = "max:aws.sqs.approximate_number_of_messages_visible{queuename:${request.value.dlq}}"
                alias_name = "DLQ ${request.key}"
              }
            }
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Backlog das filas"
          dynamic "request" {
            for_each = local.filas_monitoradas

            content {
              q            = "avg:aws.sqs.approximate_number_of_messages_visible{queuename:${request.value.fila}}"
              display_type = "line"

              metadata {
                expression = "avg:aws.sqs.approximate_number_of_messages_visible{queuename:${request.value.fila}}"
                alias_name = request.key
              }
            }
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Idade da mensagem mais antiga nas filas (s)"
          dynamic "request" {
            for_each = local.filas_monitoradas

            content {
              q            = "avg:aws.sqs.approximate_age_of_oldest_message{queuename:${request.value.fila}}"
              display_type = "line"

              metadata {
                expression = "avg:aws.sqs.approximate_age_of_oldest_message{queuename:${request.value.fila}}"
                alias_name = request.key
              }
            }
          }
        }
      }
    }
  }

  widget {
    group_definition {
      title       = "Situacao financeira indeterminada e pendencias"
      layout_type = "ordered"

      widget {
        timeseries_definition {
          title = "OS: situacao financeira indeterminada"
          request {
            q            = "sum:oficina.situacao_financeira.indeterminada{$env}.as_count()"
            display_type = "bars"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Billing: situacao financeira indeterminada"
          request {
            q            = "sum:billing.situacao_financeira_indeterminada{*}.as_count()"
            display_type = "bars"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Billing: pendencias de estorno abertas por motivo"
          request {
            q            = "sum:billing.pendencia_estorno_aberta{*} by {motivo}.as_count()"
            display_type = "bars"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Billing: operacoes financeiras indeterminadas"
          request {
            q            = "sum:billing.operacao_financeira_indeterminada{*}.as_count()"
            display_type = "bars"
          }
        }
      }
    }
  }

  widget {
    group_definition {
      title       = "Falhas tecnicas do Mercado Pago"
      layout_type = "ordered"

      widget {
        timeseries_definition {
          title = "Por operacao"
          request {
            q            = "sum:billing.mercado_pago.falha_tecnica{*} by {operacao}.as_count()"
            display_type = "bars"
          }
        }
      }

      widget {
        timeseries_definition {
          title = "Por motivo"
          request {
            q            = "sum:billing.mercado_pago.falha_tecnica{*} by {motivo}.as_count()"
            display_type = "bars"
          }
        }
      }
    }
  }

  widget {
    note_definition {
      content = "Compensacoes por motivo: nenhum servico emite metrica de compensacao por motivo, entao o painel nao as mostra (limitacao conhecida). Investigue pela busca de logs com o correlationId da OS."
    }
  }
}
