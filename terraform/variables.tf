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
  default     = "1.30"
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
