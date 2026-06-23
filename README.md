# AWS GitOps Platform - Infrastructure (DevSecOps)

Ce dépôt contient le code Terraform pour provisionner l'infrastructure Cloud AWS. **Il ne contient pas les manifestes de vos applications.**

## Architecture & Composants

*   **Infra as Code** : Terraform (AWS VPC, EKS, IRSA pour la sécurité).
*   **Autoscaling** : Karpenter (Instances Spot et On-Demand).
*   **Déploiement Continu** : ArgoCD (Installé via Helm par Terraform).
*   **Sécurité** : HashiCorp Vault + Moteur KMS pour l'auto-unseal.
*   **Sauvegardes** : Un bucket S3 dédié pour Velero.

## 🗂️ Séparation des Responsabilités (Multi-Repo)

Pour respecter les meilleures pratiques de sécurité et de séparation des privilèges, l'architecture est divisée en deux dépôts :
1. **`aws-gitops-infrastructure`** (Ce dépôt) : Provisionne le Cloud AWS (Réseau, EKS, S3, IAM) et installe ArgoCD.
2. **`aws-gitops-apps`** : Contient tous les manifestes Kubernetes (GitOps) de vos applications et outils. ArgoCD (déployé ici) est configuré pour écouter le dépôt d'applications.

## 🌍 Multi-Environnements (Staging & Prod)

L'infrastructure supporte des environnements isolés utilisant les **Workspaces Terraform**. Le nom des ressources critiques (Cluster EKS, Buckets S3, IAM Roles) est automatiquement suffixé par le nom du workspace (ex: `-stag`, `-prod`).

### 1. Déploiement Staging

```bash
cd terraform
terraform init

# Créer l'environnement staging
terraform workspace new stag
# (Ou le sélectionner s'il existe déjà)
# terraform workspace select stag

terraform plan -var="domain_name=stag.example.com"
terraform apply -var="domain_name=stag.example.com"
```

### 2. Déploiement Production

```bash
# Sélectionner l'environnement prod
terraform workspace new prod

terraform plan -var="domain_name=prod.example.com"
terraform apply -var="domain_name=prod.example.com"
```

## 🔌 Connexion au Cluster EKS (Privé)

L'endpoint API public d'EKS est désactivé par sécurité.
- **Bastion EC2** : Vous devez vous connecter via le Bastion EC2 provisionné (SSH) ou configurer un tunnel Wireguard pour exécuter vos commandes `kubectl`.
- **Terraform Cloud** : Un agent Terraform (`tfc-agent`) est déployé dans les sous-réseaux privés pour exécuter l'infrastructure en continu de manière sécurisée.

```bash
# Exemple depuis le Bastion ou VPN
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster-stag
```

## 🚀 Le Relais GitOps

Une fois Terraform appliqué, l'application ArgoCD `root-app` est déployée. Elle se connecte automatiquement au dépôt [aws-gitops-apps](https://github.com/alex-dembele/aws-gitops-apps) et commence à synchroniser le reste de l'architecture (Istio, Cert-Manager, vos apps métier, etc.).

Veuillez consulter le README du dépôt `aws-gitops-apps` pour ajouter de nouvelles applications, gérer le routage, et configurer les **Protections de branche** GitHub.

## 🛡️ Sécurité & CI

- **Tfsec** : La CI de ce dépôt exécute automatiquement des analyses de sécurité (`tfsec`) sur le code Terraform à chaque Pull Request pour garantir la non-régression sécuritaire.
- **Fuites de State** : Le `.gitignore` empêche tout commit accidentel des fichiers d'état Terraform.
