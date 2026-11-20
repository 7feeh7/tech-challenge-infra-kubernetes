variable "aws_region" {
  description = "Regiao AWS onde os recursos serao provisionados."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de deploy (homologacao ou producao)."
  type        = string

  validation {
    condition     = contains(["homologacao", "producao"], var.environment)
    error_message = "environment deve ser homologacao ou producao."
  }
}

variable "project_name" {
  description = "Nome do projeto, usado como prefixo dos recursos."
  type        = string
  default     = "tech-challenge"
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "kubernetes_version" {
  description = "Versao do Kubernetes no cluster EKS."
  type        = string
  default     = "1.37"
}

variable "operador_principal_arn" {
  description = "ARN do usuario ou role IAM do operador (autor): recebe acesso administrador ao cluster EKS e a chave KMS dele."
  type        = string

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:(user|role)/[A-Za-z0-9+=,.@_/-]+$", var.operador_principal_arn))
    error_message = "operador_principal_arn e obrigatorio e deve ser o ARN de um usuario ou role IAM (arn:aws:iam::<conta>:user/<nome> ou :role/<nome>). Em CI, defina a variable OPERADOR_PRINCIPAL_ARN do repositorio no GitHub."
  }
}

variable "node_instance_type" {
  description = "Tipo de instancia EC2 dos nodes do EKS."
  type        = string
  default     = "t3.small"
}

variable "node_desired_size" {
  description = "Quantidade desejada de nodes no managed node group."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Quantidade minima de nodes."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Quantidade maxima de nodes."
  type        = number
  default     = 4
}

variable "lambda_s3_bucket" {
  description = "Bucket S3 para artefatos das Functions (ZIP)."
  type        = string
}

variable "lambda_s3_key" {
  description = "Chave S3 padrao do ZIP de auth-cpf (sobrescrito pelo CI com SHA)."
  type        = string
  default     = "lambda-auth-cpf/placeholder.zip"
}

variable "jwt_secret" {
  description = "Obsoleto (E08): chave privada RS256 gravada pelo autor no Secrets Manager. Mantido so para compatibilidade do workflow de deploy legado."
  type        = string
  sensitive   = true
  default     = ""
}

variable "lambda_timeout" {
  description = "Timeout da Lambda em segundos."
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Memoria da Lambda em MB."
  type        = number
  default     = 256
}

variable "lambda_auth_reserved_concurrency" {
  description = "Reserved concurrency da auth-cpf, alinhada ao pool de conexoes do RDS."
  type        = number
  default     = 10
}

variable "jwt_secret_arn" {
  description = "ARN do secret JWT no Secrets Manager (preferencial em producao)."
  type        = string
  default     = ""
}

variable "jwt_issuer" {
  description = "Issuer dos tokens de cliente."
  type        = string
  default     = "tech-challenge-auth"
}

variable "jwt_audience" {
  description = "Audience dos tokens de cliente."
  type        = string
  default     = "tech-challenge-api"
}

variable "api_cors_origins" {
  description = "Origens permitidas no API Gateway."
  type        = list(string)
  default     = ["*"]
}

variable "api_throttling_burst" {
  description = "Burst limit do stage default do API Gateway."
  type        = number
  default     = 100
}

variable "api_throttling_rate" {
  description = "Rate limit do stage default do API Gateway."
  type        = number
  default     = 50
}

variable "api_integration_timeout_ms" {
  description = "Timeout das integracoes HTTP/Lambda no API Gateway (max 30000)."
  type        = number
  default     = 29000

  validation {
    condition     = var.api_integration_timeout_ms >= 50 && var.api_integration_timeout_ms <= 30000
    error_message = "api_integration_timeout_ms deve estar entre 50 e 30000."
  }
}

variable "api_log_retention_days" {
  description = "Retencao dos access logs JSON do API Gateway."
  type        = number
  default     = 14
}

variable "resend_api_key" {
  description = "Chave da API Resend consumida pela Lambda de notificacao."
  type        = string
  sensitive   = true
}

variable "resend_from_email" {
  description = "Remetente de dominio verificado no Resend."
  type        = string

  validation {
    condition = (
      can(regex("^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$", var.resend_from_email))
      && !endswith(lower(var.resend_from_email), "@seu-dominio.com")
    )
    error_message = "resend_from_email e obrigatorio e deve ser um e-mail valido, diferente do placeholder de exemplo. Em CI, defina a variable RESEND_FROM_EMAIL do repositorio no GitHub com o remetente de um dominio verificado no Resend."
  }
}

variable "lambda_notificacao_reserved_concurrency" {
  description = "Reserved concurrency da Lambda de notificacao."
  type        = number
  default     = 5
}

variable "sqs_notificacao_batch_size" {
  description = "Tamanho do lote SQS consumido pela Lambda de notificacao."
  type        = number
  default     = 10
}

variable "sqs_notificacao_max_receive_count" {
  description = "Tentativas antes de redirecionar mensagem para DLQ."
  type        = number
  default     = 5
}

variable "alarm_sqs_age_seconds" {
  description = "Limite de idade da mensagem mais antiga em cada fila monitorada (notificacao, OS, Billing e Execution)."
  type        = number
  default     = 300
}

variable "alarm_sqs_backlog_count" {
  description = "Limite de mensagens visiveis em cada fila monitorada (notificacao, OS, Billing e Execution)."
  type        = number
  default     = 100
}

variable "alarm_outbox_idade_segundos" {
  description = "Limite de idade da mensagem mais antiga pendente na outbox do OS."
  type        = number
  # Acima do prazo de reivindicacao do lote (OUTBOX_REIVINDICACAO_MS = 300 s), para nao alertar lote em publicacao.
  default = 600

  validation {
    condition     = var.alarm_outbox_idade_segundos > 0
    error_message = "alarm_outbox_idade_segundos deve ser maior que zero."
  }
}

variable "alarm_outbox_publicacao_falha_count" {
  description = "Limite de falhas de publicacao da outbox do OS em 10 minutos."
  type        = number
  default     = 5

  validation {
    condition     = var.alarm_outbox_publicacao_falha_count >= 1
    error_message = "alarm_outbox_publicacao_falha_count deve ser no minimo 1."
  }
}

variable "alarm_consumo_erro_transitorio_count" {
  description = "Limite de erros transitorios de consumo de mensagens no OS em 10 minutos."
  type        = number
  default     = 10

  validation {
    condition     = var.alarm_consumo_erro_transitorio_count >= 1
    error_message = "alarm_consumo_erro_transitorio_count deve ser no minimo 1."
  }
}

variable "alarm_consumo_erro_permanente_count" {
  description = "Limite de erros permanentes de consumo de mensagens no OS em 10 minutos (0 alerta no primeiro)."
  type        = number
  default     = 0

  validation {
    condition     = var.alarm_consumo_erro_permanente_count >= 0
    error_message = "alarm_consumo_erro_permanente_count nao pode ser negativo."
  }
}

variable "alarm_os_parada_segundos" {
  description = "Limite, em segundos, da idade da OS mais antiga em cada status com duracao. Informe so os status que mudam."
  type = object({
    EM_DIAGNOSTICO       = optional(number, 86400)
    AGUARDANDO_APROVACAO = optional(number, 259200)
    # Prazo total da reserva (75 min, D4.6) mais 15 min para a verificacao periodica e a consulta financeira.
    AGUARDANDO_PAGAMENTO = optional(number, 5400)
    AGUARDANDO_EXECUCAO  = optional(number, 172800)
    EM_EXECUCAO          = optional(number, 259200)
    # A compensacao e automatica: mais de 30 min indica compensacao parada (D4.7).
    EM_CANCELAMENTO = optional(number, 1800)
    FINALIZADA      = optional(number, 604800)
  })
  default = {}

  validation {
    condition     = alltrue([for limite in values(var.alarm_os_parada_segundos) : limite > 0])
    error_message = "Todos os limites de alarm_os_parada_segundos devem ser maiores que zero."
  }
}

variable "alarm_os_parada_sem_dado_minutos" {
  description = "Minutos sem o gauge de idade por status antes do monitor OS parada alertar (minimo 10, o dobro da janela de 5 minutos)."
  type        = number
  default     = 15

  validation {
    condition     = var.alarm_os_parada_sem_dado_minutos >= 10
    error_message = "alarm_os_parada_sem_dado_minutos deve ser no minimo 10."
  }
}

variable "alarm_situacao_financeira_indeterminada_count" {
  description = "Limite de sinais de situacao financeira indeterminada (OS e Billing) em 30 minutos (0 alerta no primeiro)."
  type        = number
  default     = 0

  validation {
    condition     = var.alarm_situacao_financeira_indeterminada_count >= 0
    error_message = "alarm_situacao_financeira_indeterminada_count nao pode ser negativo."
  }
}

variable "alarm_mercado_pago_falha_tecnica_count" {
  description = "Limite de falhas tecnicas do Mercado Pago (timeout, rede, HTTP 5xx, resposta invalida) em 10 minutos."
  type        = number
  default     = 5

  validation {
    condition     = var.alarm_mercado_pago_falha_tecnica_count >= 1
    error_message = "alarm_mercado_pago_falha_tecnica_count deve ser no minimo 1."
  }
}

variable "datadog_api_key" {
  description = "Datadog API Key para coleta de logs, metricas e APM."
  type        = string
  sensitive   = true
  default     = ""
}

variable "datadog_app_key" {
  description = "Datadog Application Key para dashboards, monitores e synthetic tests."
  type        = string
  sensitive   = true
  default     = ""
}

variable "datadog_site" {
  description = "Site Datadog (datadoghq.com ou datadoghq.eu)."
  type        = string
  default     = "datadoghq.com"
}

variable "datadog_alert_recipients" {
  description = "Destinatarios dos alertas Datadog (ex.: @slack-canal ou @email)."
  type        = string
  default     = "@all"
}

variable "auth_route_throttling_burst" {
  description = "Burst limit especifico de POST /auth/cpf no API Gateway."
  type        = number
  default     = 10
}

variable "auth_route_throttling_rate" {
  description = "Rate limit (req/s) especifico de POST /auth/cpf no API Gateway."
  type        = number
  default     = 5
}

variable "auth_cpf_max_attempts" {
  description = "Tentativas maximas por CPF na janela configurada (DynamoDB)."
  type        = number
  default     = 5
}

variable "auth_cpf_window_seconds" {
  description = "Janela em segundos do rate limit por CPF."
  type        = number
  default     = 300
}

variable "auth_response_target_ms" {
  description = "Tempo minimo uniforme de resposta da auth-cpf (anti timing attack)."
  type        = number
  default     = 300
}

variable "auth_failure_alarm_threshold" {
  description = "Limite de falhas de auth em 5 min para alarme CloudWatch."
  type        = number
  default     = 50
}

variable "github_org" {
  description = "Organizacao GitHub dos quatro repositorios."
  type        = string
  default     = "7feeh7"
}

variable "github_owner_id" {
  description = "ID numerico do owner GitHub (obrigatorio para repos criados apos 2026-07-15 — subject OIDC imutavel)."
  type        = string
  default     = "20801260"
}

variable "github_repo_app" {
  description = "Repositorio da aplicacao NestJS."
  type        = string
  default     = "tech-challenge-oficina"
}

variable "github_repo_serverless" {
  description = "Repositorio das Functions."
  type        = string
  default     = "tech-challenge-serverless"
}

variable "github_repo_infra_kubernetes" {
  description = "Repositorio Terraform EKS/Gateway."
  type        = string
  default     = "tech-challenge-infra-kubernetes"
}

variable "github_repo_infra_database" {
  description = "Repositorio Terraform RDS."
  type        = string
  default     = "tech-challenge-infra-database"
}
