resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  version          = "6.7.11" # Version du chart Helm

  set {
    name  = "server.extraArgs"
    value = "{--insecure}" # Istio gérera le TLS au niveau de la gateway
  }

  depends_on = [module.eks]
}

# Bootstrapping du "App of Apps" GitOps
# Remarque : Idéalement le `repoURL` pointerait vers votre dépôt GitHub GitOps réel
# Ici, nous mettons un placeholder pour l'architecture.
resource "kubectl_manifest" "argocd_root_app" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: root-app
      namespace: argocd
      finalizers:
      - resources-finalizer.argocd.argoproj.io
    spec:
      project: default
      source:
        repoURL: 'https://github.com/alex-dembele/aws-gitops-infrastructure.git'
        targetRevision: HEAD
        path: gitops/apps
      destination:
        server: 'https://kubernetes.default.svc'
        namespace: argocd
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  YAML

  depends_on = [helm_release.argocd]
}
