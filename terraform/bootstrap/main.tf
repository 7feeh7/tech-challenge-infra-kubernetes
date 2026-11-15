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

  boundary_workload_arn   = "arn:aws:iam::${local.account_id}:policy/${local.resource_name_prefix}-boundary-workload"
  boundary_plataforma_arn = "arn:aws:iam::${local.account_id}:policy/${local.resource_name_prefix}-boundary-plataforma"

  stack_iam_role_arns_workload = [
    "arn:aws:iam::${local.account_id}:role/${local.resource_name_prefix}-os-service",
    "arn:aws:iam::${local.account_id}:role/${local.resource_name_prefix}-billing-service",
    "arn:aws:iam::${local.account_id}:role/${local.resource_name_prefix}-execution-service",
    "arn:aws:iam::${local.account_id}:role/${local.resource_name_prefix}-db-admin-job",
    "arn:aws:iam::${local.account_id}:role/${local.resource_name_prefix}-lambda-role",
    "arn:aws:iam::${local.account_id}:role/${local.resource_name_prefix}-lambda-notificacao-role",
  ]

  stack_iam_role_arns_plataforma = [
    "arn:aws:iam::${local.account_id}:role/${local.resource_name_prefix}-cluster-autoscaler",
    "arn:aws:iam::${local.account_id}:role/${local.cluster_name}",
    "arn:aws:iam::${local.account_id}:role/${local.cluster_name}-node",
  ]

  stack_iam_role_arns = concat(local.stack_iam_role_arns_workload, local.stack_iam_role_arns_plataforma)

  bootstrap_state_prefix = "tech-challenge-infra-kubernetes/bootstrap"
  bootstrap_state_object = "${local.terraform_state_bucket_arn}/${local.bootstrap_state_prefix}/*"

  # Chave S3 de state por papel de CI (pipeline); bootstrap protegido para todas as roles.
  ci_terraform_state_prefixes = {
    app              = "tech-challenge-oficina/${var.environment}/"
    billing          = "tech-challenge-billing/${var.environment}/"
    execution        = "tech-challenge-execution/${var.environment}/"
    serverless       = ""
    infra_kubernetes = "tech-challenge-infra-kubernetes/${var.environment}/"
    infra_database   = "tech-challenge-infra-database/${var.environment}/"
  }

  ci_terraform_uses_state_lock = {
    app              = true
    billing          = true
    execution        = true
    serverless       = false
    infra_kubernetes = true
    infra_database   = true
  }

  eks_attachable_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController",
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
    "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess",
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

  # Formato imutavel GitHub (docs OIDC): IDs no segmento repo org@ownerId/name@repoId.
  github_oidc_subject = {
    for key, repo in local.github_repos :
    key => "repo:${var.github_org}@${var.github_owner_id}/${repo.name}@${repo.repo_id}:environment:${var.environment}:ref:refs/heads/main"
  }
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