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
