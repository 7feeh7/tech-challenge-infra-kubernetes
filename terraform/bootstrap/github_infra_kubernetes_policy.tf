locals {
  infra_kubernetes_secret_arns = [
    "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/jwt-*",
    "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/sendgrid-*",
    "arn:aws:secretsmanager:${var.aws_region}:${local.account_id}:secret:${local.secret_path_prefix}/token-*",
  ]

  infra_stack_sqs_arns = [
    "arn:aws:sqs:${var.aws_region}:${local.account_id}:${local.resource_name_prefix}-notificacao-status",
    "arn:aws:sqs:${var.aws_region}:${local.account_id}:${local.resource_name_prefix}-notificacao-status-dlq",
  ]

  infra_stack_sns_arns = [
    "arn:aws:sns:${var.aws_region}:${local.account_id}:${local.resource_name_prefix}-notificacao-status",
  ]

  infra_stack_ecr_arns = [
    "arn:aws:ecr:${var.aws_region}:${local.account_id}:repository/${local.resource_name_prefix}",
  ]

  infra_stack_dynamodb_arns = [
    "arn:aws:dynamodb:${var.aws_region}:${local.account_id}:table/${local.resource_name_prefix}-auth-cpf-rate",
  ]
}

# Policy de apply do stack EKS/Gateway; excecoes Checkov CKV_AWS_107-111 em .checkov.yml (compensacoes E06).
data "aws_iam_policy_document" "github_infra_kubernetes" {
  statement {
    sid    = "StackServicos"
    effect = "Allow"
    actions = [
      "acm:*",
      "apigateway:*",
      "autoscaling:*",
      "cloudwatch:*",
      "ec2:*",
      "eks:*",
      "elasticloadbalancing:*",
      "events:*",
      "logs:*",
      "route53:*",
      "ssm:*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DynamoDbStack"
    effect = "Allow"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DeleteTable",
      "dynamodb:DescribeTable",
      "dynamodb:UpdateTable",
      "dynamodb:UpdateTimeToLive",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "dynamodb:ListTagsOfResource",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = local.infra_stack_dynamodb_arns
  }

  statement {
    sid    = "SqsStack"
    effect = "Allow"
    actions = [
      "sqs:CreateQueue",
      "sqs:DeleteQueue",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:SetQueueAttributes",
      "sqs:AddPermission",
      "sqs:RemovePermission",
      "sqs:TagQueue",
      "sqs:UntagQueue",
      "sqs:ListQueueTags",
      "sqs:PurgeQueue",
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
    ]
    resources = local.infra_stack_sqs_arns
  }

  statement {
    sid    = "SnsStack"
    effect = "Allow"
    actions = [
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:GetTopicAttributes",
      "sns:SetTopicAttributes",
      "sns:Subscribe",
      "sns:Unsubscribe",
      "sns:ListSubscriptionsByTopic",
      "sns:TagResource",
      "sns:UntagResource",
      "sns:ListTagsForResource",
      "sns:Publish",
    ]
    resources = local.infra_stack_sns_arns
  }

  statement {
    # ecr:GetAuthorizationToken exige Resource * (documentacao AWS).
    sid       = "EcrAuthToken"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "EcrStack"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeRepositories",
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:PutLifecyclePolicy",
      "ecr:SetRepositoryPolicy",
      "ecr:TagResource",
      "ecr:ListImages",
    ]
    resources = local.infra_stack_ecr_arns
  }

  statement {
    sid    = "LambdaStack"
    effect = "Allow"
    actions = [
      "lambda:CreateFunction",
      "lambda:DeleteFunction",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:PublishVersion",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:TagResource",
      "lambda:UntagResource",
      "lambda:ListTags",
      "lambda:CreateEventSourceMapping",
      "lambda:DeleteEventSourceMapping",
      "lambda:GetEventSourceMapping",
      "lambda:UpdateEventSourceMapping",
      "lambda:ListEventSourceMappings",
    ]
    resources = [
      "arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${local.resource_name_prefix}-*",
    ]
  }

  statement {
    sid    = "KmsProjeto"
    effect = "Allow"
    actions = [
      "kms:CreateKey",
      "kms:CreateAlias",
      "kms:DeleteAlias",
      "kms:DescribeKey",
      "kms:EnableKeyRotation",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListAliases",
      "kms:ListResourceTags",
      "kms:PutKeyPolicy",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:UpdateKeyDescription",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:CreateGrant",
      "kms:ListGrants",
      "kms:RevokeGrant",
    ]
    resources = ["*"]
    condition {
      test     = "ForAnyValue:StringLike"
      variable = "kms:ResourceAliases"
      values   = ["alias/${local.resource_name_prefix}-*", "alias/eks/${local.cluster_name}*"]
    }
  }

  statement {
    sid    = "KmsSemAlias"
    effect = "Allow"
    actions = [
      "kms:CreateKey",
      "kms:CreateAlias",
      "kms:ListAliases",
      "kms:DescribeKey",
      "kms:TagResource",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SecretsInfraKubernetes"
    effect = "Allow"
    actions = [
      "secretsmanager:CreateSecret",
      "secretsmanager:DeleteSecret",
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:TagResource",
      "secretsmanager:UntagResource",
      "secretsmanager:ListSecretVersionIds",
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:PutResourcePolicy",
      "secretsmanager:DeleteResourcePolicy",
    ]
    resources = local.infra_kubernetes_secret_arns
  }

  statement {
    sid    = "S3LambdaArtifacts"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${var.lambda_s3_bucket}",
      "arn:aws:s3:::${var.lambda_s3_bucket}/*",
    ]
  }

  statement {
    sid    = "S3PutBucketPolicyStack"
    effect = "Allow"
    actions = [
      "s3:PutBucketPolicy",
      "s3:GetBucketPolicy",
      "s3:DeleteBucketPolicy",
    ]
    resources = [
      "arn:aws:s3:::${var.lambda_s3_bucket}",
    ]
  }

  statement {
    sid    = "IamLeituraRoles"
    effect = "Allow"
    actions = [
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
    ]
    resources = local.stack_iam_role_arns
  }

  statement {
    sid    = "IamRoleMutacaoSimples"
    effect = "Allow"
    actions = [
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:TagRole",
      "iam:UntagRole",
    ]
    resources = local.stack_iam_role_arns
  }

  statement {
    sid    = "IamWorkloadComBoundaryWorkload"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:PutRolePermissionsBoundary",
    ]
    resources = local.stack_iam_role_arns_workload
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.boundary_workload_arn]
    }
  }

  statement {
    sid    = "IamPlataformaComBoundaryPlataforma"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:PutRolePermissionsBoundary",
    ]
    resources = local.stack_iam_role_arns_plataforma
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.boundary_plataforma_arn]
    }
  }

  statement {
    sid    = "DenyBoundaryTrocaWorkload"
    effect = "Deny"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePermissionsBoundary",
    ]
    resources = local.stack_iam_role_arns_workload
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.boundary_plataforma_arn]
    }
  }

  statement {
    sid    = "DenyBoundaryTrocaPlataforma"
    effect = "Deny"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePermissionsBoundary",
    ]
    resources = local.stack_iam_role_arns_plataforma
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.boundary_workload_arn]
    }
  }

  statement {
    sid    = "IamAttachWorkload"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
    ]
    resources = local.stack_iam_role_arns_workload
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.boundary_workload_arn]
    }
    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values   = local.eks_attachable_policy_arns
    }
  }

  statement {
    sid    = "IamAttachPlataforma"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
    ]
    resources = local.stack_iam_role_arns_plataforma
    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.boundary_plataforma_arn]
    }
    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values   = local.eks_attachable_policy_arns
    }
  }

  statement {
    sid    = "IamPassRoleStack"
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    resources = local.stack_iam_role_arns
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values = [
        "lambda.amazonaws.com",
        "eks.amazonaws.com",
        "ec2.amazonaws.com",
      ]
    }
  }

  statement {
    sid    = "IamUpdateTrustStackRoles"
    effect = "Allow"
    actions = [
      "iam:UpdateAssumeRolePolicy",
    ]
    resources = local.stack_iam_role_arns
  }

  statement {
    sid    = "EksOidcProvider"
    effect = "Allow"
    actions = [
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
      "iam:ListOpenIDConnectProviders",
    ]
    resources = [
      "arn:aws:iam::${local.account_id}:oidc-provider/oidc.eks.${var.aws_region}.amazonaws.com/id/*",
    ]
  }

  statement {
    sid    = "IamServiceLinkedRoles"
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values = [
        "eks.amazonaws.com",
        "eks-nodegroup.amazonaws.com",
        "elasticloadbalancing.amazonaws.com",
        "autoscaling.amazonaws.com",
        "lambda.amazonaws.com",
        "rds.amazonaws.com",
        "apigateway.amazonaws.com",
      ]
    }
  }

  statement {
    sid    = "IamLeitura"
    effect = "Allow"
    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:ListPolicies",
      "iam:ListPolicyVersions",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "NegarStsAssumeRole"
    effect = "Deny"
    actions = [
      "sts:AssumeRole",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_infra_kubernetes" {
  name   = "${local.resource_name_prefix}-github-infra-k8s-policy"
  role   = aws_iam_role.github["infra_kubernetes"].id
  policy = data.aws_iam_policy_document.github_infra_kubernetes.json
}