terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.10"
    }
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.0"
    }
  }

  backend "s3" {}
}

locals {
  ssm_prefix   = "/tech-challenge/${var.environment}"
  dd_service   = "oficina-api"
  dd_site_host = var.datadog_site == "datadoghq.eu" ? "https://api.datadoghq.eu/" : "https://api.datadoghq.com/"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "tech-challenge-infra-kubernetes"
    }
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = local.dd_site_host
}
