resource "aws_kms_key" "vault" {
  description             = "KMS Key for Vault Auto-Unseal"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.cluster_name}-vault-kms"
  }
}

resource "aws_kms_alias" "vault" {
  name          = "alias/${var.cluster_name}-vault-auto-unseal"
  target_key_id = aws_kms_key.vault.key_id
}

module "vault_kms_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "${var.cluster_name}-vault-kms"

  role_policy_arns = {
    vault_kms = aws_iam_policy.vault_kms.arn
  }

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["vault:vault"] # Namespace et SA par défaut de Vault
    }
  }
}

resource "aws_iam_policy" "vault_kms" {
  name        = "${var.cluster_name}-vault-kms-policy"
  description = "Policy for Vault KMS Auto-Unseal"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Effect   = "Allow"
        Resource = aws_kms_key.vault.arn
      }
    ]
  })
}

output "vault_kms_key_id" {
  description = "L'ID de la clé KMS à renseigner dans la configuration Helm de Vault"
  value       = aws_kms_key.vault.key_id
}
