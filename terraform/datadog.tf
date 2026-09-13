resource "kubernetes_namespace" "datadog" {
  count = var.datadog_api_key != "" ? 1 : 0

  metadata {
    name = "datadog"
  }

  depends_on = [module.eks]
}

resource "kubernetes_secret" "datadog_api_key" {
  count = var.datadog_api_key != "" ? 1 : 0

  metadata {
    name      = "datadog-secret"
    namespace = kubernetes_namespace.datadog[0].metadata[0].name
  }

  data = {
    "api-key" = var.datadog_api_key
  }

  type = "Opaque"
}

resource "helm_release" "datadog_agent" {
  count = var.datadog_api_key != "" ? 1 : 0

  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  namespace  = kubernetes_namespace.datadog[0].metadata[0].name
  version    = "3.49.6"

  set {
    name  = "datadog.apiKeyExistingSecret"
    value = kubernetes_secret.datadog_api_key[0].metadata[0].name
  }

  set {
    name  = "datadog.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "datadog.site"
    value = var.datadog_site
  }

  set {
    name  = "datadog.tags[0]"
    value = "env:${var.environment}"
  }

  set {
    name  = "datadog.tags[1]"
    value = "project:${var.project_name}"
  }

  set {
    name  = "datadog.apm.portEnabled"
    value = "true"
  }

  set {
    name  = "datadog.apm.socketEnabled"
    value = "true"
  }

  set {
    name  = "datadog.dogstatsd.useHostPort"
    value = "true"
  }

  set {
    name  = "datadog.dogstatsd.nonLocalTraffic"
    value = "true"
  }

  set {
    name  = "datadog.dogstatsd.port"
    value = "8125"
  }

  set {
    name  = "datadog.logs.enabled"
    value = "true"
  }

  set {
    name  = "datadog.logs.containerCollectAll"
    value = "true"
  }

  set {
    name  = "datadog.processAgent.enabled"
    value = "true"
  }

  set {
    name  = "datadog.processAgent.processCollection"
    value = "true"
  }

  set {
    name  = "clusterAgent.enabled"
    value = "true"
  }

  set {
    name  = "clusterAgent.metricsProvider.enabled"
    value = "true"
  }

  set {
    name  = "datadog.orchestratorExplorer.enabled"
    value = "true"
  }

  # Segunda barreira de mascaramento no coletor (complementa sanitizacao da app).
  set {
    name  = "datadog.logs.processingRules[0].type"
    value = "mask_sequences"
  }

  set {
    name  = "datadog.logs.processingRules[0].name"
    value = "redact_sensitive"
  }

  set {
    name  = "datadog.logs.processingRules[0].pattern"
    value = "(Bearer\\s+\\S+|eyJ[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+|\\d{3}\\.?\\d{3}\\.?\\d{3}-?\\d{2})"
  }

  set {
    name  = "datadog.logs.processingRules[0].replacement"
    value = "[redacted]"
  }

  depends_on = [
    kubernetes_namespace.datadog,
    kubernetes_secret.datadog_api_key,
    module.eks,
    helm_release.cluster_autoscaler,
  ]
}
