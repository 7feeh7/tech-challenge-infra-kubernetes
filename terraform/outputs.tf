output "aws_region" {
  description = "Regiao AWS utilizada."
  value       = var.aws_region
}

output "environment" {
  description = "Ambiente provisionado."
  value       = var.environment
}

output "vpc_id" {
  description = "ID da VPC."
  value       = module.vpc.vpc_id
}

output "eks_cluster_name" {
  description = "Nome do cluster EKS."
  value       = module.eks.cluster_name
}

output "ecr_repository_url" {
  description = "URL do repositorio ECR."
  value       = aws_ecr_repository.api.repository_url
}

output "lambda_auth_function_name" {
  description = "Nome da Function de autenticacao."
  value       = aws_lambda_function.auth_cpf.function_name
}

output "lambda_artifacts_bucket" {
  description = "Bucket S3 de artefatos das Functions."
  value       = aws_s3_bucket.lambda_artifacts.id
}

output "ssm_prefix" {
  description = "Prefixo SSM deste ambiente."
  value       = local.ssm_prefix
}

output "kubeconfig_command" {
  description = "Comando para configurar kubectl."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
