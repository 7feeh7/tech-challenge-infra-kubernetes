resource "kubernetes_role" "administracao_job_manager" {
  metadata {
    name      = "administracao-job-manager"
    namespace = kubernetes_namespace.administracao.metadata[0].name
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["create", "get", "list", "watch", "delete", "patch", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "pods/log"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps", "secrets"]
    verbs      = ["get", "list", "watch", "create", "patch", "update", "delete"]
  }
}

resource "kubernetes_role_binding" "administracao_job_manager" {
  metadata {
    name      = "administracao-job-manager"
    namespace = kubernetes_namespace.administracao.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.administracao_job_manager.metadata[0].name
  }

  subject {
    kind      = "Group"
    name      = "infra-database-ci"
    api_group = "rbac.authorization.k8s.io"
  }
}