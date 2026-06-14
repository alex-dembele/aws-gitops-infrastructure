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
## 🔄 Workflow Kustomize (Staging -> Prod)

Les applications (comme l'exemple `mon-app`) utilisent **Kustomize** pour séparer les environnements :
- Le pipeline CI (`ci-cd.yml`) met à jour automatiquement l'image dans l'overlay **Staging** (`gitops/apps/mon-app/overlays/staging`). ArgoCD déploie la nouvelle version en staging.
- Une fois testé, vous pouvez aller dans l'onglet **Actions** de GitHub et déclencher manuellement le workflow **"Promote to Production"**. Il prendra le tag et mettra à jour l'overlay **Prod**, déclenchant le déploiement final.

## 🔐 Gestion des Secrets Applicatifs (Vault + ESO)

Pour injecter vos secrets sans les exposer dans Git :
1. Les secrets doivent être créés dans Vault (Moteur KV v2 au chemin `secret/data/<env>/<app>`).
2. Le `ClusterSecretStore` connecte l'**External Secrets Operator** (ESO) à Vault.
3. Le manifest `ExternalSecret` présent dans l'application ira lire la clé dans Vault et créera un `Secret` Kubernetes local, monté dans votre conteneur.

*Note: Pensez à exécuter le script `gitops/base/vault-init.sh` une fois Vault déployé pour configurer l'authentification Kubernetes initiale !*

## 🌍 Routage Multi-Domaines

Istio, Cert-Manager et ExternalDNS sont configurés pour être agnostiques vis-à-vis du domaine. Vous pouvez utiliser plusieurs domaines (ex: `*.example.com`, `*.domaine2.fr`) simplement en ajoutant les `hosts` appropriés dans les `VirtualService` et les `Certificate` ArgoCD créera les routes dynamiquement !

---

## 💰 Optimisation des Coûts (Karpenter)
Karpenter est configuré avec deux NodePools (dans `terraform/karpenter.tf`) :
- `tools-spot` : Utilise exclusivement des instances Spot (ex: t3, m5) pour les outils (CI/CD, Monitoring). Cela réduit les coûts de ~70%.
- `prod-ondemand` : Utilise des instances On-Demand pour vos applications de production critiques.

## ??? Architecture Durcie & S�curis�e (Mise � jour)

1. **S�paration des D�p�ts** : Ce d�p�t ne contient que l_infrastructure (Terraform). Les manifestes GitOps sont dans `aws-gitops-apps`.
2. **VPC Multi-NAT** : Une NAT Gateway par zone de disponibilit� pour une v�ritable Haute Disponibilit�, et des sous-r�seaux `intra` pour isoler vos ressources internes.
3. **EKS 100% Priv� & Bastion** : L_endpoint API public d_EKS est d�sactiv�.
   - Un **Bastion EC2** avec Wireguard est provisionn�. Vous pouvez vous y connecter en SSH ou via Wireguard VPN pour ex�cuter vos commandes `kubectl`.
   - Un agent Terraform Cloud (`tfc-agent`) est d�ploy� dans le VPC pour permettre � TFC d_ex�cuter les modules Helm/Kubernetes de mani�re s�curis�e.
4. **Vault HA & Auto-Unseal** : Vault fonctionne maintenant en Haute Disponibilit� avec le backend Raft. L_auto-unseal est configur� via une cl� AWS KMS d�di�e, supprimant l_intervention manuelle en cas de red�marrage.
5. **Sauvegardes (Velero)** : Un bucket S3 d�di� et un r�le IRSA permettent � Velero de sauvegarder votre cluster (manifestes et volumes EBS).
6. **Gouvernance (Kyverno)** : Le moteur de politiques Kyverno est d�ploy� pour s_assurer que seuls les conteneurs s�curis�s tournent sur votre infrastructure.

