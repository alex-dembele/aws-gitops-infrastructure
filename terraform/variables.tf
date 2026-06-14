variable "aws_region" {
  description = "Région AWS où déployer l'infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Nom du cluster EKS"
  type        = string
  default     = "gitops-eks-cluster"
}

variable "cluster_version" {
  description = "Version de Kubernetes pour EKS"
  type        = string
  default     = "1.30"
}

variable "vpc_cidr" {
  description = "CIDR du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "domain_name" {
  description = "Nom de domaine de base pour le routage (ex: example.com)"
  type        = string
  default     = "example.com"
}

variable "route53_hosted_zone_id" {
  description = "ID de la zone HostedZone Route53 (ex: Z1234567890)"
  type        = string
  default     = "Z1234567890" # A configurer par l_utilisateur
}

