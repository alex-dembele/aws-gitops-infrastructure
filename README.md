# AWS GitOps Platform - DevSecOps

Ce dépôt contient l'intégralité du code nécessaire pour déployer et opérer une architecture d'entreprise robuste, sécurisée, pilotée par GitOps sur AWS EKS.

## Architecture & Composants

*   **Infra as Code** : Terraform (AWS VPC, EKS, IRSA pour la sécurité).
*   **GitOps** : ArgoCD (Déploiement continu) + Argo Rollouts (Blue/Green, Canary).
*   **Autoscaling** : Karpenter (Instances Spot et On-Demand).
*   **Service Mesh & Routage** : Istio (Gateway et VirtualService), ExternalDNS (Route53), Cert-Manager (Let's Encrypt).
*   **Sécurité** : HashiCorp Vault (Auto-hébergé) + External Secrets Operator.
*   **Observabilité** : Kube-Prometheus-Stack, Grafana, Kiali.
*   **CI/CD** : GitHub Actions, SonarQube, Trivy.

---

## 🚀 Comment l'utiliser (Guide de démarrage)

### 1. Prérequis
- Un compte AWS avec les droits d'administration.
- Terraform installé localement (`>= 1.5.0`).
- Un compte Terraform Cloud (Optionnel mais configuré par défaut dans `providers.tf`).
- `kubectl` et `aws-cli` configurés sur votre machine.
- Un nom de domaine géré par AWS Route53 (ex: `example.com`).

### 2. Déploiement de l'Infrastructure (Terraform)
Le déploiement se fait en une seule étape qui va provisionner le cluster EKS et installer la base de Karpenter et d'ArgoCD.

```bash
cd terraform
# Initialisez le workspace Terraform
terraform init

# Vérifiez le plan d'exécution
terraform plan -var="domain_name=example.com" -var="aws_region=us-east-1"

# Appliquez les modifications (Cela prendra environ 15-20 minutes)
terraform apply -var="domain_name=example.com" -var="aws_region=us-east-1"
```

### 3. Connexion au Cluster EKS
Une fois Terraform terminé, configurez `kubectl` :
```bash
aws eks update-kubeconfig --region us-east-1 --name gitops-eks-cluster
```

### 4. GitOps (ArgoCD) prend le relais
Terraform a déjà installé ArgoCD et créé une application `root-app`. ArgoCD va automatiquement lire le contenu du dossier `gitops/` de ce dépôt et déployer le reste de l'infrastructure :

1.  **Dossier `gitops/apps`** : Contient les applications maîtresses (`base-apps.yaml`, `tools-apps.yaml`).
2.  **Dossier `gitops/base`** : Istio, Cert-Manager, ExternalDNS, Vault, External Secrets.
3.  **Dossier `gitops/tools`** : Prometheus, Grafana, Kiali, SonarQube, Argo Rollouts.

> **Note sur le dépôt GitOps** : N'oubliez pas de remplacer `https://github.com/alex-dembele/aws-gitops-infrastructure.git` par l'URL de **votre vrai dépôt GitHub** dans les fichiers `gitops/apps/*.yaml` si vous forkerez ce projet.

### 5. Accès aux Outils
Les DNS sont automatiquement créés par ExternalDNS dans Route53, et les certificats TLS sont générés par Cert-Manager via Let's Encrypt.
- **ArgoCD** : `https://argocd.stag.example.com`
- **Grafana** : `https://grafana.stag.example.com`
- **SonarQube** : `https://sonar.stag.example.com`

---

## 🔐 Configuration CI/CD et Sécurité

Le workflow GitHub Actions est prêt (`.github/workflows/ci-cd.yml`).
Pour qu'il fonctionne, vous devez ajouter ces secrets dans les paramètres de votre dépôt GitHub (`Settings > Secrets and variables > Actions`) :

*   `SONAR_TOKEN` : Token généré dans SonarQube.
*   `SONAR_HOST_URL` : URL de votre SonarQube (ex: `https://sonar.stag.example.com`).
*   `DOCKERHUB_USERNAME` et `DOCKERHUB_TOKEN` : Pour pousser les images.
*   `GITOPS_PAT` : Un Personal Access Token GitHub permettant à l'Action de commiter la mise à jour de la version de l'image Docker dans ce dépôt GitOps.

## 💰 Optimisation des Coûts (Karpenter)
Karpenter est configuré avec deux NodePools (dans `terraform/karpenter.tf`) :
- `tools-spot` : Utilise exclusivement des instances Spot (ex: t3, m5) pour les outils (CI/CD, Monitoring). Cela réduit les coûts de ~70%.
- `prod-ondemand` : Utilise des instances On-Demand pour vos applications de production critiques.
