resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faaa4048d3f995d84b9cbb7ca"]
}

resource "aws_iam_role" "github" {
  for_each = local.github_repos

  name = each.value.role

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = local.github_oidc_subject[each.key]
          }
        }
      },
    ]
  })

  tags = {
    Name   = each.value.role
    GitHub = each.value.name
  }
}

locals {
  lambda_auth_name = var.lambda_auth_function_name != "" ? var.lambda_auth_function_name : "${local.resource_name_prefix}-auth-cpf"
  lambda_noti_name = var.lambda_notificacao_function_name != "" ? var.lambda_notificacao_function_name : "${local.resource_name_prefix}-notificacao"
  lambda_auth_arn  = "arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${local.lambda_auth_name}"
  lambda_noti_arn  = "arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${local.lambda_noti_name}"

  ssm_parameter_arn = "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/tech-challenge/${var.environment}/*"

  os_ecr_repo_arn      = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${local.resource_name_prefix}"
  billing_ecr_repo_arn = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${var.project_name}-billing-${var.environment}"
  execution_ecr_arn    = "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${var.project_name}-execution-${var.environment}"

  sqs_os_prefix_arn      = "arn:aws:sqs:${var.aws_region}:${local.account_id}:${local.resource_name_prefix}-os-in*"
  sqs_billing_prefix_arn = "arn:aws:sqs:${var.aws_region}:${local.account_id}:${local.resource_name_prefix}-billing-in*"
  sqs_execution_prefix   = "arn:aws:sqs:${var.aws_region}:${local.account_id}:${local.resource_name_prefix}-execution-in*"

  dynamodb_execution_arn = "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${local.resource_name_prefix}-execution-*"

  ssm_infra_parameter_arn_prefix    = "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/tech-challenge/${var.environment}/infra"
  ssm_database_parameter_arn_prefix = "arn:aws:ssm:${var.aws_region}:${local.account_id}:parameter/tech-challenge/${var.environment}/database"

  ssm_parameter_write_actions = [
    "ssm:PutParameter",
    "ssm:DeleteParameter",
    "ssm:AddTagsToResource",
    "ssm:RemoveTagsFromResource",
    "ssm:ListTagsForResource",
  ]

  # Parametros que o proprio stack de cada repositorio publica (ssm.tf do stack).
  os_ssm_parameter_arns = [
    for name in ["os_in_queue_url", "os_in_dlq_url"] : "${local.ssm_infra_parameter_arn_prefix}/${name}"
  ]
  billing_ssm_parameter_arns = [
    for name in ["billing_ecr_repository_url", "billing_in_queue_url", "billing_in_queue_arn", "mercado_pago_secret_arn"] :
    "${local.ssm_infra_parameter_arn_prefix}/${name}"
  ]
  execution_ssm_parameter_arns = [
    for name in ["execution_in_queue_url", "execution_in_queue_arn", "execution_in_dlq_url", "execution_ecr_repository_url"] :
    "${local.ssm_infra_parameter_arn_prefix}/${name}"
  ]
  infra_database_ssm_read_arns = [
    for name in ["vpc_id", "private_subnet_ids", "lambda_security_group_id", "rds_access_security_group_id", "eks_node_security_group_id", "eks_cluster_name"] :
    "${local.ssm_infra_parameter_arn_prefix}/${name}"
  ]

  # O segredo do Mercado Pago e criado pelo stack do Billing com o prefixo do recurso (hifen), nao com o caminho dos demais segredos.
  mercado_pago_secret_arn = "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.resource_name_prefix}/mercado-pago-*"

  database_secret_arns = [
    for name in ["db-credentials", "db-user-oficina", "db-user-billing"] :
    "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/${name}-*"
  ]

  rds_arn_prefix          = "arn:aws:rds:${var.aws_region}:${local.account_id}"
  rds_instance_arn        = "${local.rds_arn_prefix}:db:${local.resource_name_prefix}-db"
  rds_subnet_group_arn    = "${local.rds_arn_prefix}:subgrp:${local.resource_name_prefix}-db-subnet"
  rds_parameter_group_arn = "${local.rds_arn_prefix}:pg:${local.resource_name_prefix}-pg16"
  rds_final_snapshot_arn  = "${local.rds_arn_prefix}:snapshot:${local.resource_name_prefix}-final"
  rds_default_option_arn  = "${local.rds_arn_prefix}:og:default:*"
}

resource "aws_iam_role_policy" "github_serverless" {
  name = "${local.resource_name_prefix}-github-serverless-policy"
  role = aws_iam_role.github["serverless"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction",
          "lambda:GetFunctionConfiguration",
          "lambda:PublishVersion",
          "lambda:WaitFunctionUpdated",
        ]
        Resource = [local.lambda_auth_arn, local.lambda_noti_arn]
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.lambda_s3_bucket}",
          "arn:aws:s3:::${var.lambda_s3_bucket}/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = local.ssm_parameter_arn
      },
    ]
  })
}

resource "aws_iam_role_policy" "github_app" {
  name = "${local.resource_name_prefix}-github-app-policy"
  role = aws_iam_role.github["app"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
        Resource = local.os_ecr_repo_arn
      },
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = local.cluster_arn
      },
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/jwt-private-*",
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/jwt-public-*",
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/db-user-oficina-*",
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/token-*-os-*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = local.ssm_parameter_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:SetQueueAttributes",
          "sqs:TagQueue",
          "sqs:UntagQueue",
          "sqs:ListQueueTags",
        ]
        Resource = local.sqs_os_prefix_arn
      },
      {
        Effect   = "Allow"
        Action   = local.ssm_parameter_write_actions
        Resource = local.os_ssm_parameter_arns
      },
      {
        # O IAM nao aceita restricao de recurso em ssm:DescribeParameters.
        Effect   = "Allow"
        Action   = ["ssm:DescribeParameters"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "github_billing" {
  name = "${local.resource_name_prefix}-github-billing-policy"
  role = aws_iam_role.github["billing"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:CreateRepository",
          "ecr:PutLifecyclePolicy",
          "ecr:TagResource",
          "ecr:UntagResource",
          "ecr:ListTagsForResource",
          "ecr:GetLifecyclePolicy",
          "ecr:DeleteLifecyclePolicy",
          "ecr:DeleteRepository",
        ]
        Resource = local.billing_ecr_repo_arn
      },
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = local.cluster_arn
      },
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/jwt-public-*",
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/db-user-billing-*",
          local.mercado_pago_secret_arn,
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/token-billing-os-*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource",
          "secretsmanager:DeleteSecret",
        ]
        Resource = local.mercado_pago_secret_arn
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = local.ssm_parameter_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:SetQueueAttributes",
          "sqs:TagQueue",
          "sqs:UntagQueue",
          "sqs:ListQueueTags",
        ]
        Resource = local.sqs_billing_prefix_arn
      },
      {
        Effect   = "Allow"
        Action   = local.ssm_parameter_write_actions
        Resource = local.billing_ssm_parameter_arns
      },
      {
        # O IAM nao aceita restricao de recurso em ssm:DescribeParameters.
        Effect   = "Allow"
        Action   = ["ssm:DescribeParameters"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "github_execution" {
  name = "${local.resource_name_prefix}-github-execution-policy"
  role = aws_iam_role.github["execution"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:CreateRepository",
          "ecr:PutLifecyclePolicy",
          "ecr:TagResource",
          "ecr:UntagResource",
          "ecr:ListTagsForResource",
          "ecr:GetLifecyclePolicy",
          "ecr:DeleteLifecyclePolicy",
          "ecr:DeleteRepository",
        ]
        Resource = local.execution_ecr_arn
      },
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = local.cluster_arn
      },
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/jwt-public-*",
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/token-execution-os-*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = local.ssm_parameter_arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:CreateQueue",
          "sqs:DeleteQueue",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:SetQueueAttributes",
          "sqs:TagQueue",
          "sqs:UntagQueue",
          "sqs:ListQueueTags",
        ]
        Resource = local.sqs_execution_prefix
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:CreateTable",
          "dynamodb:DeleteTable",
          "dynamodb:DescribeTable",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:UpdateTable",
          "dynamodb:UpdateTimeToLive",
          "dynamodb:TagResource",
          "dynamodb:UntagResource",
          "dynamodb:ListTagsOfResource",
        ]
        Resource = local.dynamodb_execution_arn
      },
      {
        Effect   = "Allow"
        Action   = local.ssm_parameter_write_actions
        Resource = local.execution_ssm_parameter_arns
      },
      {
        # O IAM nao aceita restricao de recurso em ssm:DescribeParameters.
        Effect   = "Allow"
        Action   = ["ssm:DescribeParameters"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "github_infra_database_ops" {
  name = "${local.resource_name_prefix}-github-infra-db-policy"
  role = aws_iam_role.github["infra_database"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsBancoContainer"
        Effect = "Allow"
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:ListSecretVersionIds",
        ]
        Resource = local.database_secret_arns
      },
      {
        # O Terraform grava e le a versao dos tres segredos (aws_secretsmanager_secret_version).
        Sid    = "SecretsBancoValor"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
        ]
        Resource = local.database_secret_arns
      },
      {
        Sid      = "SsmLeituraInfra"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = local.infra_database_ssm_read_arns
      },
      {
        Sid      = "SsmPublicacaoDatabase"
        Effect   = "Allow"
        Action   = concat(["ssm:GetParameter"], local.ssm_parameter_write_actions)
        Resource = "${local.ssm_database_parameter_arn_prefix}/*"
      },
      {
        # O IAM nao aceita restricao de recurso em ssm:DescribeParameters.
        Sid      = "SsmDescribeParameters"
        Effect   = "Allow"
        Action   = ["ssm:DescribeParameters"]
        Resource = "*"
      },
      {
        Sid      = "EksDescribeCluster"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = local.cluster_arn
      },
      {
        # Leituras que o provider e o RDS exigem do chamador; o EC2 nao aceita restricao de recurso nelas.
        Sid    = "Ec2Leitura"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSecurityGroupRules",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeVpcs",
        ]
        Resource = "*"
      },
      {
        Sid    = "Ec2SecurityGroupCriacao"
        Effect = "Allow"
        Action = ["ec2:CreateSecurityGroup"]
        Resource = [
          "arn:aws:ec2:${var.aws_region}:${local.account_id}:vpc/*",
          "arn:aws:ec2:${var.aws_region}:${local.account_id}:security-group/*",
        ]
      },
      {
        Sid      = "Ec2SecurityGroupTagsNaCriacao"
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = "arn:aws:ec2:${var.aws_region}:${local.account_id}:security-group/*"
        Condition = {
          StringEquals = {
            "ec2:CreateAction" = "CreateSecurityGroup"
          }
        }
      },
      {
        # Altera so o security group criado por este stack: o default_tags do provider grava ManagedBy no recurso.
        Sid    = "Ec2SecurityGroupDoStack"
        Effect = "Allow"
        Action = [
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags",
          "ec2:DeleteTags",
        ]
        Resource = "arn:aws:ec2:${var.aws_region}:${local.account_id}:security-group/*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/ManagedBy" = var.github_repo_infra_database
          }
        }
      },
      {
        Sid    = "CloudWatchAlarmesRds"
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricAlarm",
          "cloudwatch:DeleteAlarms",
          "cloudwatch:TagResource",
          "cloudwatch:UntagResource",
          "cloudwatch:ListTagsForResource",
        ]
        Resource = "arn:aws:cloudwatch:${var.aws_region}:${local.account_id}:alarm:${local.resource_name_prefix}-rds-*"
      },
      {
        # O IAM nao aceita restricao de recurso em cloudwatch:DescribeAlarms.
        Sid      = "CloudWatchDescribeAlarms"
        Effect   = "Allow"
        Action   = ["cloudwatch:DescribeAlarms"]
        Resource = "*"
      },
      {
        Sid    = "RdsInstancia"
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance",
          "rds:ModifyDBInstance",
          "rds:DeleteDBInstance",
          "rds:RebootDBInstance",
          "rds:DescribeDBInstances",
          "rds:CreateDBSnapshot",
        ]
        Resource = [
          local.rds_instance_arn,
          local.rds_subnet_group_arn,
          local.rds_parameter_group_arn,
          local.rds_default_option_arn,
          local.rds_final_snapshot_arn,
        ]
      },
      {
        # O provider le a instancia por filtro de dbi-resource-id, avaliado contra db:*; a acao e so leitura.
        Sid      = "RdsDescribeInstancias"
        Effect   = "Allow"
        Action   = ["rds:DescribeDBInstances"]
        Resource = "arn:aws:rds:${var.aws_region}:${local.account_id}:db:*"
      },
      {
        Sid    = "RdsSubnetGroup"
        Effect = "Allow"
        Action = [
          "rds:CreateDBSubnetGroup",
          "rds:ModifyDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:DescribeDBSubnetGroups",
        ]
        Resource = local.rds_subnet_group_arn
      },
      {
        Sid    = "RdsParameterGroup"
        Effect = "Allow"
        Action = [
          "rds:CreateDBParameterGroup",
          "rds:ModifyDBParameterGroup",
          "rds:ResetDBParameterGroup",
          "rds:DeleteDBParameterGroup",
          "rds:DescribeDBParameterGroups",
          "rds:DescribeDBParameters",
        ]
        Resource = local.rds_parameter_group_arn
      },
      {
        Sid    = "RdsTags"
        Effect = "Allow"
        Action = [
          "rds:AddTagsToResource",
          "rds:RemoveTagsFromResource",
          "rds:ListTagsForResource",
        ]
        Resource = [
          local.rds_instance_arn,
          local.rds_subnet_group_arn,
          local.rds_parameter_group_arn,
          local.rds_final_snapshot_arn,
        ]
      },
      {
        # Substitui o que a AmazonRDSFullAccess dava: o RDS cria sua service-linked role na primeira instancia da conta.
        Sid      = "RdsServiceLinkedRole"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "arn:aws:iam::${local.account_id}:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "rds.amazonaws.com"
          }
        }
      },
    ]
  })
}