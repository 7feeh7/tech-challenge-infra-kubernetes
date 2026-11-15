output "github_oidc_provider_arn" {
  description = "ARN do provedor OIDC do GitHub."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_ci_role_arns" {
  description = "ARNs das roles de CI por repositorio (sem segredos)."
  value = {
    for key, role in aws_iam_role.github : key => role.arn
  }
}

output "github_ci_role_names" {
  description = "Nomes das roles de CI por repositorio."
  value = {
    for key, role in aws_iam_role.github : key => role.name
  }
}