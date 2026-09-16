resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faaa4048d3f995d84b9cbb7ca"]
}

locals {
  github_repos = {
    app = {
      name = var.github_repo_app
      role = "${var.project_name}-${var.environment}-github-oficina"
    }
    serverless = {
      name = var.github_repo_serverless
      role = "${var.project_name}-${var.environment}-github-serverless"
    }
    infra_kubernetes = {
      name = var.github_repo_infra_kubernetes
      role = "${var.project_name}-${var.environment}-github-infra-k8s"
    }
    infra_database = {
      name = var.github_repo_infra_database
      role = "${var.project_name}-${var.environment}-github-infra-db"
    }
  }
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
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${each.value.name}:ref:refs/heads/main"
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
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${each.value.name}:environment:${var.environment}"
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

resource "aws_iam_role_policy" "github_serverless" {
  name = "${var.project_name}-${var.environment}-github-serverless-policy"
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
        Resource = [
          aws_lambda_function.auth_cpf.arn,
          aws_lambda_function.notificacao.arn,
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.lambda_artifacts.arn,
          "${aws_s3_bucket.lambda_artifacts.arn}/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/tech-challenge/${var.environment}/*"
      },
    ]
  })
}

resource "aws_iam_role_policy" "github_app" {
  name = "${var.project_name}-${var.environment}-github-app-policy"
  role = aws_iam_role.github["app"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster"]
        Resource = module.eks.cluster_arn
      },
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          aws_secretsmanager_secret.jwt.arn,
          var.db_secret_arn != "" ? var.db_secret_arn : "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/tech-challenge/${var.environment}/*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_infra_kubernetes" {
  role       = aws_iam_role.github["infra_kubernetes"].name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

resource "aws_iam_role_policy_attachment" "github_infra_database" {
  role       = aws_iam_role.github["infra_database"].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

# Role OIDC de CI para Terraform do repo infra-database (PowerUser + SSM/Secrets).
#tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_role_policy" "github_infra_database_ssm" {
  name = "${var.project_name}-${var.environment}-github-infra-db-ssm"
  role = aws_iam_role.github["infra_database"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:*",
          "ssm:*",
          "ec2:*",
          "cloudwatch:*",
          "logs:*",
          "iam:GetRole",
          "iam:PassRole",
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:DeleteRole",
          "iam:TagRole",
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::${var.project_name}-terraform-state-*",
          "arn:aws:s3:::${var.project_name}-terraform-state-*/*",
        ]
      },
    ]
  })
}

resource "aws_iam_role_policy" "github_infra_k8s_state" {
  name = "${var.project_name}-${var.environment}-github-infra-k8s-state"
  role = aws_iam_role.github["infra_kubernetes"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:*"]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/*"
      },
      {
        Effect = "Allow"
        Action = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [
          "arn:aws:s3:::${var.project_name}-terraform-state-*",
          "arn:aws:s3:::${var.project_name}-terraform-state-*/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["iam:*"]
        Resource = "*"
      },
    ]
  })
}
