locals {
  ci_role_names = {
    app              = "${var.project_name}-${var.environment}-github-oficina"
    billing          = "${var.project_name}-${var.environment}-github-billing"
    execution        = "${var.project_name}-${var.environment}-github-execution"
    serverless       = "${var.project_name}-${var.environment}-github-serverless"
    infra_kubernetes = "${var.project_name}-${var.environment}-github-infra-k8s"
    infra_database   = "${var.project_name}-${var.environment}-github-infra-db"
  }

  ci_role_arns = {
    for key, name in local.ci_role_names :
    key => "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${name}"
  }

  irsa_role_names = {
    os_service = "${var.project_name}-${var.environment}-os-service"
    billing    = "${var.project_name}-${var.environment}-billing-service"
    execution  = "${var.project_name}-${var.environment}-execution-service"
    db_admin   = "${var.project_name}-${var.environment}-db-admin-job"
  }

  sqs_queue_arns = {
    os_in            = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-${var.environment}-os-in"
    os_in_dlq        = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-${var.environment}-os-in-dlq"
    billing_in       = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-${var.environment}-billing-in"
    billing_in_dlq   = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-${var.environment}-billing-in-dlq"
    execution_in     = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-${var.environment}-execution-in"
    execution_in_dlq = "arn:aws:sqs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-${var.environment}-execution-in-dlq"
  }
}