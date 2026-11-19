resource "aws_iam_policy" "boundary_workload" {
  name        = "${local.resource_name_prefix}-boundary-workload"
  description = "Teto para IRSAs e roles de execucao das Lambdas (complemento E06)."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "MensageriaEEventos"
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:SendMessage",
          "sqs:ChangeMessageVisibility",
          "sqs:ListQueues",
          "sns:Publish",
          "sns:GetTopicAttributes",
        ]
        Resource = [
          "arn:aws:sqs:${var.aws_region}:${local.account_id}:${local.resource_name_prefix}-*",
          "arn:aws:sns:${var.aws_region}:${local.account_id}:${local.resource_name_prefix}-*",
        ]
      },
      {
        Sid    = "DynamoDbExecution"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:ConditionCheckItem",
          "dynamodb:DescribeTable",
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${local.resource_name_prefix}-execution-*"
      },
      # Tabela de rate limit da auth-cpf. Statement proprio, so com a operacao que o codigo da Lambda usa e o ARN exato:
      # o teto de execution-* nao pode crescer para quem nao precisa dele.
      {
        Sid      = "DynamoDbAuthCpfRate"
        Effect   = "Allow"
        Action   = ["dynamodb:UpdateItem"]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${local.resource_name_prefix}-auth-cpf-rate"
      },
      {
        Sid    = "SecretsLeitura"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/*"
      },
      # Negar vale mais que permitir: nenhuma policy anexada a uma role workload (inclusive pela CI) alcanca estes
      # segredos, que so tem um consumidor de runtime legitimo cada.
      {
        Sid      = "NegarChavePrivadaJwtForaDaAuthCpf"
        Effect   = "Deny"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/jwt-private-*"
        Condition = {
          ArnNotEquals = {
            "aws:PrincipalArn" = local.lambda_auth_role_arn
          }
        }
      },
      {
        Sid      = "NegarSegredoMasterBancoForaDoJobAdmin"
        Effect   = "Deny"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/db-credentials-*"
        Condition = {
          ArnNotEquals = {
            "aws:PrincipalArn" = local.db_admin_job_role_arn
          }
        }
      },
      {
        Sid      = "KmsViaServico"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = [
              "secretsmanager.${var.aws_region}.amazonaws.com",
              "sqs.${var.aws_region}.amazonaws.com",
              "sns.${var.aws_region}.amazonaws.com",
              "dynamodb.${var.aws_region}.amazonaws.com",
            ]
          }
        }
      },
      {
        Sid    = "LogsLambda"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${local.account_id}:*"
      },
      {
        Sid    = "LambdaVpcEni"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses",
        ]
        Resource = "*"
      },
      {
        Sid    = "XRayLambda"
        Effect = "Allow"
        Action = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_policy" "boundary_plataforma" {
  name        = "${local.resource_name_prefix}-boundary-plataforma"
  description = "Teto para roles do EKS, node group e cluster-autoscaler (complemento E06)."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EksEC2ELB"
        Effect   = "Allow"
        Action   = ["eks:*", "ec2:*", "elasticloadbalancing:*", "autoscaling:*"]
        Resource = "*"
      },
      {
        Sid    = "EcrLeitura"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
        ]
        Resource = "*"
      },
      {
        Sid      = "ObservabilidadeEKs"
        Effect   = "Allow"
        Action   = ["logs:*", "cloudwatch:*"]
        Resource = "*"
      },
      {
        Sid      = "KmsPlataforma"
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey", "kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"]
        Resource = "*"
      },
      {
        Sid      = "IamServiceLinkedRole"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole", "iam:GetRole"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = [
              "eks.amazonaws.com",
              "eks-nodegroup.amazonaws.com",
              "elasticloadbalancing.amazonaws.com",
              "autoscaling.amazonaws.com",
              "spot.amazonaws.com",
              "spotfleet.amazonaws.com",
            ]
          }
        }
      },
    ]
  })
}