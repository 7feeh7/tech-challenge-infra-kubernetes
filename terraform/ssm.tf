resource "aws_ssm_parameter" "vpc_id" {
  name  = "${local.ssm_prefix}/infra/vpc_id"
  type  = "String"
  value = module.vpc.vpc_id
}

resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "${local.ssm_prefix}/infra/private_subnet_ids"
  type  = "StringList"
  value = join(",", module.vpc.private_subnets)
}

resource "aws_ssm_parameter" "public_subnet_ids" {
  name  = "${local.ssm_prefix}/infra/public_subnet_ids"
  type  = "StringList"
  value = join(",", module.vpc.public_subnets)
}

resource "aws_ssm_parameter" "eks_cluster_name" {
  name  = "${local.ssm_prefix}/infra/eks_cluster_name"
  type  = "String"
  value = module.eks.cluster_name
}

resource "aws_ssm_parameter" "eks_cluster_endpoint" {
  name  = "${local.ssm_prefix}/infra/eks_cluster_endpoint"
  type  = "String"
  value = module.eks.cluster_endpoint
}

resource "aws_ssm_parameter" "eks_cluster_ca" {
  name  = "${local.ssm_prefix}/infra/eks_cluster_ca"
  type  = "String"
  value = module.eks.cluster_certificate_authority_data
}

resource "aws_ssm_parameter" "ecr_repository_url" {
  name  = "${local.ssm_prefix}/infra/ecr_repository_url"
  type  = "String"
  value = aws_ecr_repository.api.repository_url
}

resource "aws_ssm_parameter" "lambda_auth_function_name" {
  name  = "${local.ssm_prefix}/infra/lambda_auth_function_name"
  type  = "String"
  value = aws_lambda_function.auth_cpf.function_name
}

resource "aws_ssm_parameter" "lambda_auth_function_arn" {
  name  = "${local.ssm_prefix}/infra/lambda_auth_function_arn"
  type  = "String"
  value = aws_lambda_function.auth_cpf.arn
}

resource "aws_ssm_parameter" "lambda_notificacao_function_name" {
  name  = "${local.ssm_prefix}/infra/lambda_notificacao_function_name"
  type  = "String"
  value = aws_lambda_function.notificacao.function_name
}

resource "aws_ssm_parameter" "lambda_notificacao_function_arn" {
  name  = "${local.ssm_prefix}/infra/lambda_notificacao_function_arn"
  type  = "String"
  value = aws_lambda_function.notificacao.arn
}

resource "aws_ssm_parameter" "sns_notificacao_topic_arn" {
  name  = "${local.ssm_prefix}/infra/sns_notificacao_topic_arn"
  type  = "String"
  value = aws_sns_topic.notificacao_status.arn
}

resource "aws_ssm_parameter" "sqs_notificacao_queue_url" {
  name  = "${local.ssm_prefix}/infra/sqs_notificacao_queue_url"
  type  = "String"
  value = aws_sqs_queue.notificacao_status.url
}

resource "aws_ssm_parameter" "sqs_notificacao_dlq_url" {
  name  = "${local.ssm_prefix}/infra/sqs_notificacao_dlq_url"
  type  = "String"
  value = aws_sqs_queue.notificacao_status_dlq.url
}

resource "aws_ssm_parameter" "sendgrid_secret_arn" {
  name  = "${local.ssm_prefix}/infra/sendgrid_secret_arn"
  type  = "String"
  value = aws_secretsmanager_secret.sendgrid_api_key.arn
}

resource "aws_ssm_parameter" "jwt_secret_arn" {
  name  = "${local.ssm_prefix}/infra/jwt_secret_arn"
  type  = "String"
  value = aws_secretsmanager_secret.jwt.arn
}

resource "aws_ssm_parameter" "github_role_app_arn" {
  name  = "${local.ssm_prefix}/infra/github_role_app_arn"
  type  = "String"
  value = aws_iam_role.github["app"].arn
}

resource "aws_ssm_parameter" "github_role_serverless_arn" {
  name  = "${local.ssm_prefix}/infra/github_role_serverless_arn"
  type  = "String"
  value = aws_iam_role.github["serverless"].arn
}

resource "aws_ssm_parameter" "github_role_infra_kubernetes_arn" {
  name  = "${local.ssm_prefix}/infra/github_role_infra_kubernetes_arn"
  type  = "String"
  value = aws_iam_role.github["infra_kubernetes"].arn
}

resource "aws_ssm_parameter" "github_role_infra_database_arn" {
  name  = "${local.ssm_prefix}/infra/github_role_infra_database_arn"
  type  = "String"
  value = aws_iam_role.github["infra_database"].arn
}

resource "aws_ssm_parameter" "auth_rate_limit_table" {
  name  = "${local.ssm_prefix}/infra/auth_rate_limit_table"
  type  = "String"
  value = aws_dynamodb_table.auth_cpf_rate_limit.name
}

resource "aws_ssm_parameter" "api_notificacao_irsa_role_arn" {
  name  = "${local.ssm_prefix}/infra/api_notificacao_irsa_role_arn"
  type  = "String"
  value = aws_iam_role.api_notificacao_irsa.arn
}

resource "aws_ssm_parameter" "api_gateway_url" {
  name  = "${local.ssm_prefix}/infra/api_gateway_url"
  type  = "String"
  value = aws_apigatewayv2_api.main.api_endpoint
}

resource "aws_ssm_parameter" "api_gateway_auth_url" {
  name  = "${local.ssm_prefix}/infra/api_gateway_auth_url"
  type  = "String"
  value = "${aws_apigatewayv2_api.main.api_endpoint}/auth/cpf"
}

resource "aws_ssm_parameter" "vpc_link_id" {
  name  = "${local.ssm_prefix}/infra/vpc_link_id"
  type  = "String"
  value = aws_apigatewayv2_vpc_link.eks.id
}

resource "aws_ssm_parameter" "eks_nlb_dns_name" {
  name  = "${local.ssm_prefix}/infra/eks_nlb_dns_name"
  type  = "String"
  value = aws_lb.eks_internal.dns_name
}

resource "aws_ssm_parameter" "lambda_artifacts_bucket" {
  name  = "${local.ssm_prefix}/infra/lambda_artifacts_bucket"
  type  = "String"
  value = aws_s3_bucket.lambda_artifacts.id
}

resource "aws_ssm_parameter" "rds_access_sg_id" {
  name  = "${local.ssm_prefix}/infra/rds_access_security_group_id"
  type  = "String"
  value = aws_security_group.rds_access.id
}

resource "aws_ssm_parameter" "lambda_sg_id" {
  name  = "${local.ssm_prefix}/infra/lambda_security_group_id"
  type  = "String"
  value = aws_security_group.lambda.id
}

resource "aws_ssm_parameter" "eks_node_security_group_id" {
  name  = "${local.ssm_prefix}/infra/eks_node_security_group_id"
  type  = "String"
  value = module.eks.node_security_group_id
}
