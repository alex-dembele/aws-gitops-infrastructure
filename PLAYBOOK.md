# 📖 SRE / Infra Playbook : Opérations AWS & EKS

Ce Playbook documente les opérations courantes nécessaires à la gestion de la couche basse de l'infrastructure AWS, gérée via Terraform.

## 1. 🌍 Gestion des Environnements (Terraform Workspaces)

L'infrastructure utilise les **Workspaces Terraform** pour garantir l'isolation complète des environnements (ex: staging, uat, prod) tout en partageant le même code (DRY). Le cluster EKS, les rôles IAM, et les buckets S3 seront automatiquement suffixés par le nom de l'environnement.

### Créer un nouvel environnement (ex: `staging`)
```bash
cd terraform
terraform init

# Créer l'environnement
terraform workspace new staging

# Pré-visualiser les ressources AWS à créer
terraform plan -var="domain_name=staging.example.com" -var="cluster_version=1.29"

# Appliquer et provisionner l'infra
terraform apply -var="domain_name=staging.example.com" -var="cluster_version=1.29"
```

### Naviguer entre les environnements existants
```bash
# Lister les environnements
terraform workspace list

# Passer sur l'environnement de production (Attention au prochain "apply" !)
terraform workspace select prod
```

---

## 2. ⚡ Autoscaling & Capacité (Karpenter)

Karpenter agit comme le moteur de Provisioning Just-In-Time pour Kubernetes, remplaçant le Cluster Autoscaler. Il réagit en quelques secondes aux pods en état *Pending*.

### a. Modifier la taille maximale du cluster
Les limites globales de consommation de Karpenter sont définies dans les CRDs `NodePool` (`terraform/karpenter.tf`).
1. Éditez `karpenter.tf`.
2. Repérez le `NodePool` souhaité (ex: `prod-ondemand`).
3. Modifiez les limites :
```yaml
      limits:
        cpu: 200     # Limite augmentée à 200 vCPUs
        memory: 400Gi
```
4. Exécutez `terraform apply`.

### b. Ajouter ou interdire certains types d'instances
Si vous souhaitez autoriser les instances ARM (ex: t4g) ou interdire des séries d'instances trop coûteuses, agissez sur les `requirements` du NodePool :
```yaml
          requirements:
            - key: "karpenter.k8s.aws/instance-family"
              operator: In
              values: ["m5", "c5", "t4g"] # Ajout de t4g
```

---

## 3. 🔐 Connexion au Cluster EKS (Endpoint Privé)

Pour des raisons de haute sécurité métier, l'accès public à l'API Kubernetes (`https://...yl4.us-east-1.eks.amazonaws.com`) est **désactivé**. 

Pour utiliser `kubectl`, deux choix :
- **Bastion EC2** : Connectez-vous en SSH au Bastion situé dans le réseau public de votre VPC. De là, vous aurez accès au réseau privé EKS.
- **Client VPN Client-to-Site** : Si Wireguard ou OpenVPN a été installé sur AWS, connectez-vous au VPN.

Une fois dans le réseau sécurisé, générez votre fichier KubeConfig :
```bash
aws eks update-kubeconfig --region <votre-region> --name <nom-du-cluster-selon-workspace>
```

---

## 4. 🦺 Reprise après Sinistre (Disaster Recovery avec Velero)

Velero (installé via la stack apps mais dont le stockage S3 est géré ici) sauvegarde de manière planifiée l'état du cluster Kubernetes (Manifestes + Volumes persistants EBS).

### Sauvegarde Manuelle Pré-Maintenance
Avant une opération sensible (upgrade EKS ou Terraform apply massif), lancez une sauvegarde manuelle :
```bash
# Lance une sauvegarde en nommant le backup
velero backup create pre-upgrade-eks-129 --wait
```

### Restauration
En cas de perte du cluster, une fois le cluster recréé vierge par Terraform, installez uniquement Velero puis lancez :
```bash
# Vérifier la liste des backups sur le S3
velero backup get

# Restaurer le cluster à l'état du backup
velero restore create --from-backup pre-upgrade-eks-129
```

---

## 5. 🤖 Terraform Cloud (TFC) et Automatisation CI/CD

L'infrastructure est connectée à **Terraform Cloud** de manière native. Il est inutile (et déconseillé pour éviter les conflits de locks d'état) d'utiliser d'autres outils d'automatisation Terraform comme Atlantis.

**Workflow VCS-Driven natif :**
1. Un développeur ou SRE modifie un fichier Terraform sur une nouvelle branche et crée une **Pull Request** sur GitHub.
2. Terraform Cloud (via son intégration GitHub App) intercepte la PR. 
3. TFC exécute un `terraform plan` de manière isolée et sécurisée.
4. TFC commente **directement dans la Pull Request GitHub** avec les résultats spéculatifs du *Plan*.
5. Si tous les tests (Tfsec) passent et que la PR est approuvée puis **Mergée** sur `main`, Terraform Cloud exécute automatiquement le `terraform apply`.

> [!TIP]
> **Vérification d'activation** : Assurez-vous d'avoir lié votre espace de travail TFC à votre repo GitHub via *Settings > Version Control*, et cochez "Automatic speculative plans".

---

## 6. 🔄 Procédure de mise à jour d'EKS (Upgrades)

EKS déprécie rapidement les anciennes versions de Kubernetes. Pour mettre à jour l'environnement sans interruption, nous utilisons une approche progressive.

**Règle d'or :** L'Upgrade ne doit JAMAIS être effectué en production sans avoir été testé sur l'environnement de *Staging*.

### Procédure étape par étape :

1. **Pré-requis** : Vérifier sur les Release Notes d'AWS EKS que les APIs dépréciées ont été supprimées de vos manifestes applicatifs.
2. **Upgrade du Control Plane** : Modifiez `terraform/eks.tf` (ou passez une variable) pour indiquer la nouvelle version (ex: `cluster_version = "1.30"`). Exécutez le `terraform plan` et `apply` (ou laissez TFC le faire).
3. **Mise à jour des Nœuds via Karpenter (Blue/Green NodePool)** :
   Plutôt que de faire un recyclage in-place dangereux, créez un nouveau NodePool/EC2NodeClass dédié à la nouvelle version :
   - Dupliquez les CRDs Karpenter actuelles dans `terraform/karpenter.tf` en changeant leurs noms (ex: `prod-ondemand-130`).
   - Appliquez ce changement. Le cluster possède maintenant 2 NodePools.
4. **Cordon de l'Acien NodePool** : Taint/Cordonnez l'ancien NodePool Karpenter (ex: `prod-ondemand`) afin que plus aucun pod ne puisse s'y créer.
5. **Draining (Eviction)** : Supprimez les CRDs de l'ancien NodePool via `kubectl delete nodepool prod-ondemand`. Karpenter va **automatiquement** drainer gracieusement l'ancien NodePool, les pods seront recréés, ce qui forcera Karpenter à demander de nouvelles instances basées sur le *nouveau* NodePool (`prod-ondemand-130`).
6. **Validation** : Vérifiez que tous les noeuds en service exploitent la bonne version de la kubelet.

---
*Fin du document d'infrastructure.*
