data "aws_iam_policy_document" "os_service_irsa_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      values   = ["system:serviceaccount:oficina:oficina-api"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "os_service_irsa" {
  name               = local.irsa_role_names.os_service
  assume_role_policy = data.aws_iam_policy_document.os_service_irsa_assume.json
}

resource "aws_iam_role_policy" "os_service_runtime" {
  name = "${local.irsa_role_names.os_service}-runtime"
  role = aws_iam_role.os_service_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.notificacao_status.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
        ]
        Resource = [local.sqs_queue_arns.os_in, local.sqs_queue_arns.os_in_dlq]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes",
        ]
        Resource = [
          local.sqs_queue_arns.billing_in,
          local.sqs_queue_arns.execution_in,
        ]
      },
    ]
  })
}

moved {
  from = aws_iam_role.api_notificacao_irsa
  to   = aws_iam_role.os_service_irsa
}

moved {
  from = aws_iam_role_policy.api_notificacao_sns_publish
  to   = aws_iam_role_policy.os_service_runtime
}

data "aws_iam_policy_document" "billing_irsa_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      values   = ["system:serviceaccount:billing:billing-api"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "billing_irsa" {
  name               = local.irsa_role_names.billing
  assume_role_policy = data.aws_iam_policy_document.billing_irsa_assume.json
}

resource "aws_iam_role_policy" "billing_runtime" {
  name = "${local.irsa_role_names.billing}-runtime"
  role = aws_iam_role.billing_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
        ]
        Resource = [local.sqs_queue_arns.billing_in, local.sqs_queue_arns.billing_in_dlq]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes",
        ]
        Resource = [local.sqs_queue_arns.os_in]
      },
    ]
  })
}

data "aws_iam_policy_document" "execution_irsa_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      values   = ["system:serviceaccount:execution:execution-api"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "execution_irsa" {
  name               = local.irsa_role_names.execution
  assume_role_policy = data.aws_iam_policy_document.execution_irsa_assume.json
}

#tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_role_policy" "execution_runtime" {
  name = "${local.irsa_role_names.execution}-runtime"
  role = aws_iam_role.execution_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility",
        ]
        Resource = [local.sqs_queue_arns.execution_in, local.sqs_queue_arns.execution_in_dlq]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes",
        ]
        Resource = [local.sqs_queue_arns.os_in]
      },
      {
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
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.project_name}-${var.environment}-execution-*"
      },
    ]
  })
}

data "aws_iam_policy_document" "db_admin_job_irsa_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:sub"
      values   = ["system:serviceaccount:administracao:db-admin-job"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_provider, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "db_admin_job_irsa" {
  name               = local.irsa_role_names.db_admin
  assume_role_policy = data.aws_iam_policy_document.db_admin_job_irsa_assume.json
}

#tfsec:ignore:aws-iam-no-policy-wildcards
resource "aws_iam_role_policy" "db_admin_job_secrets" {
  name = "${local.irsa_role_names.db_admin}-secrets"
  role = aws_iam_role.db_admin_job_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/db-credentials-*",
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/db-user-*",
        ]
      },
    ]
  })
}