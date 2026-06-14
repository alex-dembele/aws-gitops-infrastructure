# Installation de Karpenter via Helm
resource "helm_release" "karpenter" {
  namespace        = "kube-system"
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = "0.36.2" # Mettre à jour selon les versions supportées

  set {
    name  = "settings.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter.iam_role_arn
  }

  set {
    name  = "settings.interruptionQueueName"
    value = module.karpenter.queue_name
  }

  depends_on = [
    module.eks,
    module.karpenter
  ]
}

# Déploiement des NodePools Karpenter
# Nous utilisons kubectl pour appliquer ces manifests car le provider helm ne gère pas
# la création des CRDs à temps si on les inclut dans un template helm
resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [helm_release.karpenter]
}

resource "kubectl_manifest" "karpenter_nodepool_tools" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: tools-spot
    spec:
      template:
        spec:
          requirements:
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot"]
            - key: "karpenter.k8s.aws/instance-family"
              operator: In
              values: ["t3", "m5"]
            - key: "kubernetes.io/arch"
              operator: In
              values: ["amd64"]
          nodeClassRef:
            apiVersion: karpenter.k8s.aws/v1beta1
            kind: EC2NodeClass
            name: default
      limits:
        cpu: 100
        memory: 200Gi
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s
  YAML

  depends_on = [kubectl_manifest.karpenter_node_class]
}

resource "kubectl_manifest" "karpenter_nodepool_prod" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: prod-ondemand
    spec:
      template:
        spec:
          requirements:
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]
            - key: "karpenter.k8s.aws/instance-family"
              operator: In
              values: ["m5", "c5"]
            - key: "kubernetes.io/arch"
              operator: In
              values: ["amd64"]
          nodeClassRef:
            apiVersion: karpenter.k8s.aws/v1beta1
            kind: EC2NodeClass
            name: default
      limits:
        cpu: 100
        memory: 200Gi
      disruption:
        consolidationPolicy: WhenUnderutilized
        expireAfter: 720h # 30 jours
  YAML

  depends_on = [kubectl_manifest.karpenter_node_class]
}
