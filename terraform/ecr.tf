# MUTABLE: CI do tech-challenge publica tag "latest" a cada deploy; manifests
# aplicados usam sempre {git_sha}. Criptografia AES-256 gerenciada pela AWS.
#tfsec:ignore:aws-ecr-enforce-immutable-repository
#tfsec:ignore:aws-ecr-repository-customer-key
resource "aws_ecr_repository" "api" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecr"
  }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Manter apenas as 10 imagens mais recentes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
