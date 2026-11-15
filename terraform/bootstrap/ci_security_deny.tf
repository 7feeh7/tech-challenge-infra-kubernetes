data "aws_iam_policy_document" "github_ci_security_deny" {
  statement {
    sid    = "DenyBoundaryPolicyMutation"
    effect = "Deny"
    actions = [
      "iam:CreatePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:DeletePolicy",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = [
      aws_iam_policy.boundary_workload.arn,
      aws_iam_policy.boundary_plataforma.arn,
    ]
  }

  statement {
    sid    = "DenyRemoveRoleBoundary"
    effect = "Deny"
    actions = [
      "iam:DeleteRolePermissionsBoundary",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "DenyGitHubCiRolesMutation"
    effect = "Deny"
    actions = [
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:PutRolePermissionsBoundary",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.resource_name_prefix}-github-*"]
  }

  statement {
    sid    = "DenyPassGitHubCiRoles"
    effect = "Deny"
    actions = [
      "iam:PassRole",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/${local.resource_name_prefix}-github-*"]
  }

  statement {
    sid    = "DenyGitHubOidcProviderMutation"
    effect = "Deny"
    actions = [
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:RemoveClientIDFromOpenIDConnectProvider",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
    ]
    resources = [aws_iam_openid_connect_provider.github.arn]
  }
}

resource "aws_iam_role_policy" "github_ci_security_deny" {
  for_each = aws_iam_role.github

  name   = "${local.resource_name_prefix}-github-${each.key}-security-deny"
  role   = each.value.id
  policy = data.aws_iam_policy_document.github_ci_security_deny.json
}