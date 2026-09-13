resource "datadog_dashboard" "tecnico" {
  count = var.datadog_app_key != "" ? 1 : 0

  title       = "Tech Challenge - Observabilidade Tecnica"
  description = "Throughput, erros, latencia, uptime, recursos Kubernetes e saturacao."
  layout_type = "ordered"

  template_variable {
    name    = "env"
    prefix  = "env"
    default = var.environment
  }

  template_variable {
    name    = "service"
    prefix  = "service"
    default = local.dd_service
  }

  template_variable {
    name    = "version"
    prefix  = "version"
    default = "*"
  }

  widget {
    group_definition {
      title       = "API"
      layout_type = "ordered"

      widget {
        query_value_definition {
          title = "Requests/s"
          request {
            q          = "sum:trace.fastify.request.hits{$env,$service,$version}.as_rate()"
            aggregator = "avg"
          }
        }
      }

      widget {
        query_value_definition {
          title = "Taxa de erro %"
          request {
            q = "100 * sum:trace.fastify.request.errors{$env,$service,$version}.as_rate() / clamp_min(sum:trace.fastify.request.hits{$env,$service,$version}.as_rate(), 0.001)"
          }
        }
      }

      widget {
        query_value_definition {
          title = "Latencia P95 (ms)"
          request {
            q = "p95:trace.fastify.request{$env,$service,$version} * 1000"
          }
        }
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Latencia P50/P95/P99"
      request {
        q            = "p50:trace.fastify.request{$env,$service,$version} * 1000"
        display_type = "line"
      }
      request {
        q            = "p95:trace.fastify.request{$env,$service,$version} * 1000"
        display_type = "line"
      }
      request {
        q            = "p99:trace.fastify.request{$env,$service,$version} * 1000"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Kubernetes - CPU e memoria"
      request {
        q            = "avg:kubernetes.cpu.usage.total{kube_deployment:oficina-api,kube_namespace:oficina,$env} by {pod_name}"
        display_type = "line"
      }
      request {
        q            = "avg:kubernetes.memory.usage{kube_deployment:oficina-api,kube_namespace:oficina,$env} by {pod_name}"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Pods, restarts e saturacao"
      request {
        q            = "sum:kubernetes.pods.running{kube_deployment:oficina-api,kube_namespace:oficina,$env}"
        display_type = "bars"
      }
      request {
        q            = "sum:kubernetes.containers.restarts{kube_deployment:oficina-api,kube_namespace:oficina,$env}.as_count()"
        display_type = "line"
      }
    }
  }

  widget {
    query_value_definition {
      title = "Uptime healthcheck"
      request {
        q = "avg:synthetics.test.success{service:${local.dd_service},env:${var.environment}}"
      }
    }
  }
}

resource "datadog_dashboard" "negocio" {
  count = var.datadog_app_key != "" ? 1 : 0

  title       = "Tech Challenge - Ordens de Servico"
  description = "Volume diario de OS e tempo medio por Diagnostico, Execucao e Finalizacao."
  layout_type = "ordered"

  template_variable {
    name    = "env"
    prefix  = "environment"
    default = var.environment
  }

  template_variable {
    name    = "status"
    prefix  = "status"
    default = "*"
  }

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
    query_value_definition {
      title = "Tempo medio EM_DIAGNOSTICO (s)"
      request {
        q = "avg:oficina.ordem_servico.tempo_por_status{$env,status:EM_DIAGNOSTICO}"
      }
    }
  }

  widget {
    query_value_definition {
      title = "Tempo medio EM_EXECUCAO (s)"
      request {
        q = "avg:oficina.ordem_servico.tempo_por_status{$env,status:EM_EXECUCAO}"
      }
    }
  }

  widget {
    query_value_definition {
      title = "Tempo medio FINALIZADA (s)"
      request {
        q = "avg:oficina.ordem_servico.tempo_por_status{$env,status:FINALIZADA}"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Duracao por status"
      request {
        q            = "avg:oficina.ordem_servico.tempo_por_status{$env,$status} by {status}"
        display_type = "line"
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

resource "datadog_dashboard" "integracoes" {
  count = var.datadog_app_key != "" ? 1 : 0

  title       = "Tech Challenge - Integracoes"
  description = "Erros e latencia de PostgreSQL, SNS/SQS, SendGrid, Secrets Manager e Functions."
  layout_type = "ordered"

  template_variable {
    name    = "env"
    prefix  = "environment"
    default = var.environment
  }

  template_variable {
    name    = "integration"
    prefix  = "integration"
    default = "*"
  }

  widget {
    timeseries_definition {
      title = "Falhas por integracao"
      request {
        q            = "sum:oficina.integracao.falha{$env,$integration} by {integration}.as_count()"
        display_type = "bars"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Latencia por integracao (ms)"
      request {
        q            = "avg:oficina.integracao.latencia{$env,$integration} by {integration,result}"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "SQS backlog e idade"
      request {
        q            = "avg:aws.sqs.approximate_number_of_messages_visible{queuename:${var.project_name}-${var.environment}-notificacao-status}"
        display_type = "line"
      }
      request {
        q            = "avg:aws.sqs.approximate_age_of_oldest_message{queuename:${var.project_name}-${var.environment}-notificacao-status}"
        display_type = "line"
      }
    }
  }

  widget {
    timeseries_definition {
      title = "Lambda notificacao - erros"
      request {
        q            = "sum:aws.lambda.errors{functionname:${var.project_name}-${var.environment}-notificacao}.as_count()"
        display_type = "bars"
      }
    }
  }
}
