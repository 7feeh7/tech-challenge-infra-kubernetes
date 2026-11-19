resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = module.vpc.vpc_id

  # O NLB nao tem security group (D6.4), entao a saida e liberada para as subnets privadas onde ele vive, so na porta
  # do listener do OS. A auth-cpf nao acessa mais o banco: consulta o cliente pela rota interna do OS.
  egress {
    from_port   = local.servicos_borda.os.porta_listener
    to_port     = local.servicos_borda.os.porta_listener
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
    description = "HTTP to internal NLB (OS)"
  }

  # Secrets Manager e DynamoDB (rate limit) via NAT Gateway, sem VPC endpoints por custo. Os enderecos das APIs AWS
  # mudam, entao o destino nao pode ser restringido por CIDR.
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #tfsec:ignore:aws-ec2-no-public-egress-sgr
    description = "HTTPS for AWS services"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-lambda-sg"
  }
}

resource "aws_security_group" "rds_access" {
  name        = "${var.project_name}-${var.environment}-rds-access-sg"
  description = "Security group for RDS access from Lambda and EKS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
    description     = "PostgreSQL from Lambda"
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "PostgreSQL from VPC (EKS nodes)"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
    description = "Responses within VPC only"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-access-sg"
  }
}

resource "aws_security_group_rule" "eks_nodes_app_ingress" {
  type              = "ingress"
  from_port         = 3000
  to_port           = 3000
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = module.eks.node_security_group_id
  description       = "Allow in-VPC traffic to API pods"
}

resource "aws_security_group_rule" "eks_nodes_nodeport_ingress" {
  type              = "ingress"
  from_port         = 30080
  to_port           = 30080
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = module.eks.node_security_group_id
  description       = "Allow NLB health checks and traffic via NodePort"
}

# Billing e Execution: a NodePort recebe o trafego do NLB e os health checks do target group, ambos com origem na VPC.
resource "aws_security_group_rule" "eks_nodes_nodeport_servico_ingress" {
  for_each = local.servicos_borda_aditivos

  type              = "ingress"
  from_port         = each.value.node_port
  to_port           = each.value.node_port
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = module.eks.node_security_group_id
  description       = "Allow NLB health checks and traffic via NodePort (${each.key})"
}
