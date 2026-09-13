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

  enable_cluster_creator_admin_permissions = true

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
