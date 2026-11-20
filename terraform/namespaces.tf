resource "kubernetes_namespace" "oficina" {
  metadata {
    name = "oficina"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = var.project_name
    }
  }
}

resource "kubernetes_namespace" "billing" {
  metadata {
    name = "billing"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = var.project_name
    }
  }
}

resource "kubernetes_namespace" "execution" {
  metadata {
    name = "execution"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = var.project_name
    }
  }
}

resource "kubernetes_namespace" "administracao" {
  metadata {
    name = "administracao"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "app.kubernetes.io/part-of"    = var.project_name
    }
  }
}

resource "kubernetes_service_account" "oficina_api" {
  metadata {
    name      = "oficina-api"
    namespace = kubernetes_namespace.oficina.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.os_service_irsa.arn
    }
  }
}

resource "kubernetes_service_account" "billing_api" {
  metadata {
    name      = "billing-api"
    namespace = kubernetes_namespace.billing.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.billing_irsa.arn
    }
  }
}

resource "kubernetes_service_account" "execution_api" {
  metadata {
    name      = "execution-api"
    namespace = kubernetes_namespace.execution.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.execution_irsa.arn
    }
  }
}

resource "kubernetes_service_account" "db_admin_job" {
  metadata {
    name      = "db-admin-job"
    namespace = kubernetes_namespace.administracao.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.db_admin_job_irsa.arn
    }
  }
}