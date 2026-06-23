data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "velero" {
  bucket = "${local.cluster_name}-velero-backups-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "velero" {
  bucket = aws_s3_bucket.velero.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "velero" {
  bucket = aws_s3_bucket.velero.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

module "velero_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name             = "${local.cluster_name}-velero"
  attach_velero_policy  = true
  velero_s3_bucket_arns = [aws_s3_bucket.velero.arn]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["velero:velero-server"]
    }
  }
}

output "velero_s3_bucket" {
  description = "Nom du bucket S3 pour les backups Velero"
  value       = aws_s3_bucket.velero.id
}
