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

  cluster_endpoint_public_access = true

  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  create_kms_key = true
  cluster_encryption_config = {
    resources = ["secrets"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Identidade fixa: evita drift quando CI (role OIDC) e apply local (user IAM) divergem.
  enable_cluster_creator_admin_permissions = false

  kms_key_administrators = [
    local.ci_role_arns.infra_kubernetes,
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/github-actions",
  ]

  access_entries = {
    github_actions_bootstrap = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/github-actions"
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
