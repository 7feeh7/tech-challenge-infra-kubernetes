resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-${var.environment}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "PostgreSQL access to RDS"
  }

  # Secrets Manager e demais APIs AWS via NAT Gateway (sem VPC endpoints por custo).
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
