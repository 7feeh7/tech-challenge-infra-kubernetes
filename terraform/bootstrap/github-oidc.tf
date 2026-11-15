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
    Statement = flatten([
      for suffix in local.github_oidc_subject_suffixes : [
        {
          Effect = "Allow"
          Principal = {
            Federated = aws_iam_openid_connect_provider.github.arn
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
              "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${each.value.name}:${suffix}"
            }
          }
        },
        {
          Effect = "Allow"
          Principal = {
            Federated = aws_iam_openid_connect_provider.github.arn
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
              "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}@${var.github_owner_id}/${each.value.name}@${each.value.repo_id}:${suffix}"
            }
          }
        },
      ]
    ])
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
          "lambda:UpdateFunctionConfiguration",
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
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/jwt-secret-*",
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/jwt-private-*",
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
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [local.terraform_state_bucket_arn, "${local.terraform_state_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = local.terraform_lock_table_arn
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
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/mercado-pago-*",
          "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/token-billing-os-*",
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
        Resource = local.sqs_billing_prefix_arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [local.terraform_state_bucket_arn, "${local.terraform_state_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = local.terraform_lock_table_arn
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
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [local.terraform_state_bucket_arn, "${local.terraform_state_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = local.terraform_lock_table_arn
      },
    ]
  })
}

#tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_role_policy" "github_infra_kubernetes" {
  name = "${local.resource_name_prefix}-github-infra-k8s-policy"
  role = aws_iam_role.github["infra_kubernetes"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "acm:*",
          "apigateway:*",
          "autoscaling:*",
          "cloudwatch:*",
          "dynamodb:*",
          "ec2:*",
          "ecr:*",
          "eks:*",
          "elasticloadbalancing:*",
          "events:*",
          "logs:*",
          "kms:*",
          "lambda:*",
          "route53:*",
          "s3:*",
          "sns:*",
          "sqs:*",
          "ssm:*",
          "secretsmanager:*",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PassRole",
        ]
        Resource = "arn:aws:iam::${local.account_id}:role/${local.resource_name_prefix}-*"
      },
      {
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = [
              "eks.amazonaws.com",
              "eks-nodegroup.amazonaws.com",
              "elasticloadbalancing.amazonaws.com",
              "autoscaling.amazonaws.com",
            ]
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [local.terraform_state_bucket_arn, "${local.terraform_state_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = local.terraform_lock_table_arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_infra_database" {
  role       = aws_iam_role.github["infra_database"].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

resource "aws_iam_role_policy" "github_infra_database_ops" {
  name = "${local.resource_name_prefix}-github-infra-db-policy"
  role = aws_iam_role.github["infra_database"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:TagResource",
          "secretsmanager:ListSecretVersionIds",
        ]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "ssm:GetParametersByPath",
        ]
        Resource = local.ssm_parameter_arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags",
          "ec2:DeleteTags",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["cloudwatch:*", "logs:*"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [local.terraform_state_bucket_arn, "${local.terraform_state_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = local.terraform_lock_table_arn
      },
    ]
  })
}