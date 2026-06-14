output "cluster_name" {
  description = "Nom du cluster EKS"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint API du cluster EKS"
  value       = module.eks.cluster_endpoint
}

output "karpenter_iam_role_arn" {
  description = "ARN du rôle IAM utilisé par Karpenter"
  value       = module.karpenter.iam_role_arn
}

output "external_dns_iam_role_arn" {
  description = "ARN du rôle IAM pour ExternalDNS"
  value       = module.external_dns_irsa_role.iam_role_arn
}

output "cert_manager_iam_role_arn" {
  description = "ARN du rôle IAM pour Cert-Manager"
  value       = module.cert_manager_irsa_role.iam_role_arn
}
