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
*Fin du document d'infrastructure.*
