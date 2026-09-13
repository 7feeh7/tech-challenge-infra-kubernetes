resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project_name}-${var.environment}-api"
  protocol_type = "HTTP"
  description   = "Entrada publica da solucao (auth CPF e rotas versionadas)"

  cors_configuration {
    allow_origins = var.api_cors_origins
    allow_methods = ["GET", "POST", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = [
      "Content-Type",
      "Authorization",
      "X-Correlation-Id",
      "Idempotency-Key",
    ]
    expose_headers = ["X-Correlation-Id"]
    max_age        = 300
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-api"
  }
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}-api"
  retention_in_days = var.api_log_retention_days

  tags = {
    Name = "${var.project_name}-${var.environment}-api-logs"
  }
}

resource "aws_apigatewayv2_integration" "lambda_auth" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.auth_cpf.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
  timeout_milliseconds   = var.api_integration_timeout_ms
}

resource "aws_apigatewayv2_integration" "eks_app" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = aws_lb_listener.eks.arn
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.eks.id
  timeout_milliseconds   = var.api_integration_timeout_ms
  payload_format_version = "1.0"
}

resource "aws_apigatewayv2_route" "auth_cpf" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /auth/cpf"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_auth.id}"
}

resource "aws_apigatewayv2_route" "auth_cpf_options" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "OPTIONS /auth/cpf"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_auth.id}"
}

resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.eks_app.id}"
}

resource "aws_apigatewayv2_route" "docs" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /docs"
  target    = "integrations/${aws_apigatewayv2_integration.eks_app.id}"
}

resource "aws_apigatewayv2_route" "docs_assets" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /docs/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.eks_app.id}"
}

resource "aws_apigatewayv2_route" "api_all" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /v1/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.eks_app.id}"
}

resource "aws_apigatewayv2_route" "api_options" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "OPTIONS /v1/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.eks_app.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      ip                 = "$context.identity.sourceIp"
      requestTime        = "$context.requestTime"
      httpMethod         = "$context.httpMethod"
      routeKey           = "$context.routeKey"
      status             = "$context.status"
      protocol           = "$context.protocol"
      responseLength     = "$context.responseLength"
      integrationError   = "$context.integrationErrorMessage"
      errorMessage       = "$context.error.message"
      integrationLatency = "$context.integrationLatency"
      correlationId      = "$context.requestId"
    })
  }

  default_route_settings {
    throttling_burst_limit = var.api_throttling_burst
    throttling_rate_limit  = var.api_throttling_rate
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-api-default-stage"
  }
}

resource "aws_lambda_permission" "api_gateway_auth_cpf" {
  statement_id  = "AllowAPIGatewayInvokeAuthCpf"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth_cpf.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# =============================================================================
# Internal NLB for EKS (API Gateway connects via VPC Link)
# =============================================================================

resource "aws_security_group" "nlb" {
  name        = "${var.project_name}-${var.environment}-nlb-sg"
  description = "Security group for internal NLB"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow HTTP from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-nlb-sg"
  }
}

resource "aws_lb" "eks_internal" {
  name               = "${var.project_name}-${var.environment}-eks-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = module.vpc.private_subnets

  enable_cross_zone_load_balancing = true

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-nlb"
  }
}

resource "aws_lb_target_group" "eks_nodes" {
  name        = "${var.project_name}-${var.environment}-eks-tg"
  port        = 30080
  protocol    = "TCP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    port                = "30080"
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-tg"
  }
}

resource "aws_lb_listener" "eks" {
  load_balancer_arn = aws_lb.eks_internal.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_nodes.arn
  }
}

resource "aws_autoscaling_attachment" "eks_nodes" {
  autoscaling_group_name = module.eks.eks_managed_node_groups["default"].node_group_autoscaling_group_names[0]
  lb_target_group_arn    = aws_lb_target_group.eks_nodes.arn
}

# =============================================================================
# VPC Link for API Gateway to NLB
# =============================================================================

resource "aws_security_group" "vpc_link" {
  name        = "${var.project_name}-${var.environment}-vpc-link-sg"
  description = "Security group for API Gateway VPC Link"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Allow HTTP from VPC to NLB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc-link-sg"
  }
}

resource "aws_apigatewayv2_vpc_link" "eks" {
  name               = "${var.project_name}-${var.environment}-eks-vpc-link"
  security_group_ids = [aws_security_group.vpc_link.id]
  subnet_ids         = module.vpc.private_subnets

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-vpc-link"
  }
}
