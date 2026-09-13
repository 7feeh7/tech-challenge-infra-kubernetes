data "aws_iam_policy_document" "api_notificacao_assume_role" {
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

resource "aws_iam_role" "api_notificacao_irsa" {
  name               = "${var.project_name}-${var.environment}-api-notificacao"
  assume_role_policy = data.aws_iam_policy_document.api_notificacao_assume_role.json
}

resource "aws_iam_role_policy" "api_notificacao_sns_publish" {
  name = "${var.project_name}-${var.environment}-api-sns-publish"
  role = aws_iam_role.api_notificacao_irsa.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.notificacao_status.arn
      }
    ]
  })
}
