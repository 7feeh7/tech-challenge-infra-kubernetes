data "aws_iam_policy_document" "github_ci_terraform_state" {
  for_each = local.github_repos

  statement {
    sid    = "DenyBootstrapStateAll"
    effect = "Deny"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:GetObjectVersion",
      "s3:DeleteObjectVersion",
    ]
    resources = [local.bootstrap_state_object]
  }

  dynamic "statement" {
    for_each = local.ci_terraform_state_prefixes[each.key] != "" ? [1] : []
    content {
      sid    = "ListOwnTerraformState"
      effect = "Allow"
      actions = [
        "s3:ListBucket",
        "s3:GetBucketLocation",
      ]
      # Sem condicao de s3:prefix: no primeiro init o state ainda nao existe, e o HeadObject so recebe 404
      # (state vazio) quando a role tem ListBucket avaliavel sem prefixo; com a condicao o S3 devolve 403
      # e o init aborta. Listar expoe apenas nomes de chaves; leitura e escrita continuam restritas ao prefixo.
      resources = [local.terraform_state_bucket_arn]
    }
  }

  dynamic "statement" {
    for_each = local.ci_terraform_state_prefixes[each.key] != "" ? [1] : []
    content {
      sid    = "ReadWriteOwnTerraformState"
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:GetObjectVersion",
      ]
      resources = [
        "${local.terraform_state_bucket_arn}/${trimsuffix(local.ci_terraform_state_prefixes[each.key], "/")}/*",
      ]
    }
  }

  dynamic "statement" {
    for_each = local.ci_terraform_uses_state_lock[each.key] ? [1] : []
    content {
      sid    = "TerraformStateLockOwn"
      effect = "Allow"
      actions = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
      ]
      resources = [local.terraform_lock_table_arn]
    }
  }

}

resource "aws_iam_role_policy" "github_ci_terraform_state" {
  for_each = local.github_repos

  name   = "${local.resource_name_prefix}-github-${each.key}-terraform-state"
  role   = aws_iam_role.github[each.key].id
  policy = data.aws_iam_policy_document.github_ci_terraform_state[each.key].json
}