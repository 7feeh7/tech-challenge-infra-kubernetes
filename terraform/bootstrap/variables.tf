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

variable "github_org" {
  description = "Organizacao GitHub dos repositorios."
  type        = string
  default     = "7feeh7"
}

variable "github_owner_id" {
  description = "ID numerico do owner GitHub (subject OIDC imutavel para repos novos)."
  type        = string
  default     = "20801260"
}

variable "github_repo_app" {
  description = "Repositorio da aplicacao OS."
  type        = string
  default     = "tech-challenge-oficina"
}

variable "github_repo_app_id" {
  description = "ID numerico do repositorio OS no GitHub."
  type        = string
  default     = "1233401444"
}

variable "github_repo_billing" {
  description = "Repositorio do Billing."
  type        = string
  default     = "tech-challenge-billing"
}

variable "github_repo_billing_id" {
  description = "ID numerico do repositorio Billing no GitHub."
  type        = string
  default     = "1459061151"
}

variable "github_repo_execution" {
  description = "Repositorio do Execution."
  type        = string
  default     = "tech-challenge-execution"
}

variable "github_repo_execution_id" {
  description = "ID numerico do repositorio Execution no GitHub."
  type        = string
  default     = "1459062232"
}

variable "github_repo_serverless" {
  description = "Repositorio das Functions."
  type        = string
  default     = "tech-challenge-serverless"
}

variable "github_repo_serverless_id" {
  description = "ID numerico do repositorio serverless no GitHub."
  type        = string
  default     = "1368447888"
}

variable "github_repo_infra_kubernetes" {
  description = "Repositorio Terraform EKS/Gateway."
  type        = string
  default     = "tech-challenge-infra-kubernetes"
}

variable "github_repo_infra_kubernetes_id" {
  description = "ID numerico do repositorio infra-kubernetes no GitHub."
  type        = string
  default     = "1367702489"
}

variable "github_repo_infra_database" {
  description = "Repositorio Terraform RDS."
  type        = string
  default     = "tech-challenge-infra-database"
}

variable "github_repo_infra_database_id" {
  description = "ID numerico do repositorio infra-database no GitHub."
  type        = string
  default     = "1360712493"
}

variable "lambda_s3_bucket" {
  description = "Bucket S3 de artefatos das Lambdas (convencao de nome)."
  type        = string
  default     = "tech-challenge-lambda-artifacts-producao"
}

variable "lambda_auth_function_name" {
  description = "Nome da Function auth-cpf (convencao de nome)."
  type        = string
  default     = ""
}

variable "lambda_notificacao_function_name" {
  description = "Nome da Function notificacao (convencao de nome)."
  type        = string
  default     = ""
}