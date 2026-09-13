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

output "api_gateway_url" {
  description = "URL base HTTPS do API Gateway (entrada publica unica)."
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "api_gateway_auth_url" {
  description = "URL publica de autenticacao por CPF."
  value       = "${aws_apigatewayv2_api.main.api_endpoint}/auth/cpf"
}

output "api_gateway_id" {
  description = "ID do HTTP API Gateway."
  value       = aws_apigatewayv2_api.main.id
}

output "vpc_link_id" {
  description = "ID do VPC Link para integracao com o EKS."
  value       = aws_apigatewayv2_vpc_link.eks.id
}

output "eks_nlb_dns_name" {
  description = "DNS do NLB interno (somente in-VPC)."
  value       = aws_lb.eks_internal.dns_name
}

output "datadog_dashboard_tecnico_url" {
  description = "URL do dashboard tecnico Datadog."
  value = length(datadog_dashboard.tecnico) > 0 ? nonsensitive(
    "https://app.${var.datadog_site}/dashboard/${datadog_dashboard.tecnico[0].id}"
  ) : null
}

output "datadog_dashboard_negocio_url" {
  description = "URL do dashboard de negocio Datadog."
  value = length(datadog_dashboard.negocio) > 0 ? nonsensitive(
    "https://app.${var.datadog_site}/dashboard/${datadog_dashboard.negocio[0].id}"
  ) : null
}

output "datadog_dashboard_integracoes_url" {
  description = "URL do dashboard de integracoes Datadog."
  value = length(datadog_dashboard.integracoes) > 0 ? nonsensitive(
    "https://app.${var.datadog_site}/dashboard/${datadog_dashboard.integracoes[0].id}"
  ) : null
}
