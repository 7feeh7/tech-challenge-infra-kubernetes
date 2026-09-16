moved {
  from = module.eks.aws_eks_access_entry.this["cluster_creator"]
  to   = module.eks.aws_eks_access_entry.this["github_actions_bootstrap"]
}

moved {
  from = module.eks.aws_eks_access_policy_association.this["cluster_creator_admin"]
  to   = module.eks.aws_eks_access_policy_association.this["github_actions_bootstrap_admin"]
}
