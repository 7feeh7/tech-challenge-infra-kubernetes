# Endpoint publico: CI do repo tech-challenge roda kubectl a partir de runners
# GitHub-hosted (IPs dinamicos). Acesso continua exigindo IAM + RBAC do EKS.
# Egress dos nodes: pull de imagens e chamadas AWS via NAT Gateway.
#tfsec:ignore:aws-eks-no-public-cluster-access
#tfsec:ignore:aws-eks-no-public-cluster-access-to-cidr
#tfsec:ignore:aws-ec2-no-public-egress-sgr
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  iam_role_name                 = local.cluster_name
  iam_role_use_name_prefix      = false
  iam_role_permissions_boundary = local.permissions_boundary_plataforma_arn
  # Sem EKS Auto Mode: evita a policy extra <role do cluster> que a role do CI nao pode criar.
  enable_auto_mode_custom_tags = false

  cluster_endpoint_public_access = true

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  create_kms_key = true
  cluster_encryption_config = {
    resources = ["secrets"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Administradores declarados (CI e operador): o criador do cluster varia conforme quem executa o apply e geraria drift.
  enable_cluster_creator_admin_permissions = false

  kms_key_administrators = [
    local.ci_role_arns.infra_kubernetes,
    var.operador_principal_arn,
  ]

  access_entries = {
    operador = {
      principal_arn = var.operador_principal_arn
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    github_infra_kubernetes = {
      principal_arn = local.ci_role_arns.infra_kubernetes
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    github_app = {
      principal_arn = local.ci_role_arns.app
      policy_associations = {
        oficina = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = ["oficina"]
          }
        }
      }
    }
    github_billing = {
      principal_arn = local.ci_role_arns.billing
      policy_associations = {
        billing = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = ["billing"]
          }
        }
      }
    }
    github_execution = {
      principal_arn = local.ci_role_arns.execution
      policy_associations = {
        execution = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = ["execution"]
          }
        }
      }
    }
    github_infra_database = {
      principal_arn     = local.ci_role_arns.infra_database
      kubernetes_groups = ["infra-database-ci"]
      policy_associations = {
        administracao = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
          access_scope = {
            type       = "namespace"
            namespaces = ["administracao"]
          }
        }
      }
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]

      desired_size = var.node_desired_size
      min_size     = var.node_min_size
      max_size     = var.node_max_size

      iam_role_name                 = "${local.cluster_name}-node"
      iam_role_use_name_prefix      = false
      iam_role_permissions_boundary = local.permissions_boundary_plataforma_arn

      # Amazon Linux 2 nao tem AMI otimizada para o EKS a partir do 1.34; explicito para nao depender do padrao do modulo.
      ami_type = "AL2023_x86_64_STANDARD"

      tags = local.cluster_autoscaler_asg_tags
    }
  }
}

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  depends_on = [module.eks]
}
