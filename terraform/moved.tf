moved {
  from = module.eks.aws_eks_access_entry.this["cluster_creator"]
  to   = module.eks.aws_eks_access_entry.this["operador"]
}

moved {
  from = module.eks.aws_eks_access_policy_association.this["cluster_creator_admin"]
  to   = module.eks.aws_eks_access_policy_association.this["operador_admin"]
}

moved {
  from = aws_secretsmanager_secret.jwt
  to   = aws_secretsmanager_secret.jwt_private
}


# Monitores de fila passaram de count para for_each por servico; o da notificacao mantem o estado.
moved {
  from = datadog_monitor.sqs_backlog[0]
  to   = datadog_monitor.sqs_backlog["notificacao"]
}

moved {
  from = datadog_monitor.sqs_age[0]
  to   = datadog_monitor.sqs_age["notificacao"]
}

moved {
  from = datadog_monitor.sqs_dlq[0]
  to   = datadog_monitor.sqs_dlq["notificacao"]
}
