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

output "permissions_boundary_arns" {
  description = "ARNs das permissions boundaries gerenciadas no bootstrap."
  value = {
    workload   = aws_iam_policy.boundary_workload.arn
    plataforma = aws_iam_policy.boundary_plataforma.arn
  }
}

output "github_oidc_subject_customization" {
  description = "Payload para gh api de customizacao do subject OIDC (formato imutavel, docs GitHub)."
  value = {
    use_default            = false
    include_claim_keys     = ["repo", "repository_owner_id", "repository_id", "context", "ref"]
    immutable_repo_segment = "repo:<org>@<owner_id>/<repo>@<repo_id>"
    required_suffix        = "environment:${var.environment}:ref:refs/heads/main"
  }
}

output "github_oidc_subjects_by_repo" {
  description = "Subject completo esperado por repositorio apos customizacao (producao + main)."
  value       = local.github_oidc_subject
}