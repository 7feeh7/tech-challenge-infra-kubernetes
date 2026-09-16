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
  default     = "1.31"
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
  description = "Segredo JWT para a Function de autenticacao."
  type        = string
  sensitive   = true
}

variable "db_secret_arn" {
  description = "ARN do secret do banco (preenchido apos deploy do repo database)."
  type        = string
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

variable "sendgrid_api_key" {
  description = "Chave da API SendGrid consumida pela Lambda de notificacao."
  type        = string
  sensitive   = true
}

variable "sendgrid_from_email" {
  description = "Remetente verificado no SendGrid."
  type        = string
  default     = "oficina@seu-dominio.com"
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
  description = "Limite de idade da mensagem mais antiga na fila de notificacao."
  type        = number
  default     = 300
}

variable "alarm_sqs_backlog_count" {
  description = "Limite de mensagens visiveis na fila de notificacao."
  type        = number
  default     = 100
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
