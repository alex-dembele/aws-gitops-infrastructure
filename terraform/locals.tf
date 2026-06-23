locals {
  # Si on est dans le workspace par défaut, on garde le nom standard, sinon on ajoute le suffixe du workspace (ex: -stag, -prod)
  cluster_name = terraform.workspace == "default" ? var.cluster_name : "${var.cluster_name}-${terraform.workspace}"
}
