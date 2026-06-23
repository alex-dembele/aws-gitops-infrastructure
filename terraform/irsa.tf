# -----------------------------------------------------------------------------
# 1. Karpenter Controller IRSA
# -----------------------------------------------------------------------------
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"

  cluster_name = module.eks.cluster_name

  # Karpenter doit pouvoir provisionner des instances EC2
  enable_pod_identity             = true
  create_pod_identity_association = true

  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

# -----------------------------------------------------------------------------
# 2. ExternalDNS IRSA
# Permet à ExternalDNS de modifier Route53 pour créer des enregistrements
# -----------------------------------------------------------------------------
module "external_dns_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name                     = "${local.cluster_name}-external-dns"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = ["arn:aws:route53:::hostedzone/${var.route53_hosted_zone_id}"]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"] # namespace et SA utilisés par ExternalDNS
    }
  }
}

# -----------------------------------------------------------------------------
# 3. Cert-Manager IRSA
# Permet à Cert-Manager de faire du DNS-01 challenge sur Route53
# -----------------------------------------------------------------------------
module "cert_manager_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name                     = "${local.cluster_name}-cert-manager"
  attach_cert_manager_policy    = true
  cert_manager_hosted_zone_arns = ["arn:aws:route53:::hostedzone/${var.route53_hosted_zone_id}"]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["cert-manager:cert-manager"]
    }
  }
}

# -----------------------------------------------------------------------------
# 4. Vault (AWS Auth / Auto-Unseal optionnel) - Préparation pour External Secrets
# -----------------------------------------------------------------------------
# Note: Ce rôle est utile si Vault nécessite de communiquer avec AWS (ex: KMS)
# ou pour que l'External Secrets Operator puisse assumer un rôle IAM si on
# s'intègre directement à AWS Secrets Manager. Pour ce projet, nous utilisons Vault,
# donc nous aurons besoin d'IRSA si Vault est stocké sur S3 (backend) ou KMS.
