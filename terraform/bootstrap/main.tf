terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {}
}

data "aws_caller_identity" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  cluster_name = "${var.project_name}-${var.environment}-eks"
  cluster_arn  = "arn:aws:eks:${var.aws_region}:${local.account_id}:cluster/${local.cluster_name}"

  resource_name_prefix = "${var.project_name}-${var.environment}"
  secret_path_prefix   = "${var.project_name}/${var.environment}"

  github_oidc_subject_suffixes = [
    "ref:refs/heads/main",
    "environment:${var.environment}",
  ]

  github_repos = {
    app = {
      name    = var.github_repo_app
      repo_id = var.github_repo_app_id
      role    = "${local.resource_name_prefix}-github-oficina"
    }
    billing = {
      name    = var.github_repo_billing
      repo_id = var.github_repo_billing_id
      role    = "${local.resource_name_prefix}-github-billing"
    }
    execution = {
      name    = var.github_repo_execution
      repo_id = var.github_repo_execution_id
      role    = "${local.resource_name_prefix}-github-execution"
    }
    serverless = {
      name    = var.github_repo_serverless
      repo_id = var.github_repo_serverless_id
      role    = "${local.resource_name_prefix}-github-serverless"
    }
    infra_kubernetes = {
      name    = var.github_repo_infra_kubernetes
      repo_id = var.github_repo_infra_kubernetes_id
      role    = "${local.resource_name_prefix}-github-infra-k8s"
    }
    infra_database = {
      name    = var.github_repo_infra_database
      repo_id = var.github_repo_infra_database_id
      role    = "${local.resource_name_prefix}-github-infra-db"
    }
  }

  terraform_state_bucket_arn = "arn:aws:s3:::${var.project_name}-terraform-state-*"
  terraform_lock_table_arn   = "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${var.project_name}-terraform-lock"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "tech-challenge-infra-kubernetes-bootstrap"
    }
  }
}