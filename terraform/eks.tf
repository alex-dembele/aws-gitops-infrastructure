module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access  = false
  cluster_endpoint_private_access = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # Active OIDC pour permettre l'utilisation d'IRSA (IAM Roles for Service Accounts)
  enable_irsa = true

  # Nous utilisons l'add-on EKS Pod Identity (recommandé par AWS) en plus de l'OIDC classique
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  # Un groupe de noeuds géré par défaut (MNG) très minimal.
  # Karpenter s'occupera du reste de l'autoscaling.
  eks_managed_node_groups = {
    initial = {
      instance_types = ["t3.medium"]

      min_size     = 2
      max_size     = 3
      desired_size = 2

      # Nécessaire pour Karpenter
      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  # Configuration des tags de sécurité requis par Karpenter
  node_security_group_tags = {
    "karpenter.sh/discovery" = local.cluster_name
  }
}
