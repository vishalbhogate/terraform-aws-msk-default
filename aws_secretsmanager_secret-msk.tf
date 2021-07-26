resource "aws_secretsmanager_secret" "msk_secret" {
  count = var.enabled && var.client_sasl_scram_enabled ? 1 : 0
  name = join("_",["AmazonMSK", var.cluster_instance, var.sm_suffix ])
  kms_key_id = aws_kms_key.kms[0].arn
  recovery_window_in_days = 0
  tags = merge({
      "Name" = join("_",["AmazonMSK", var.cluster_instance, var.sm_suffix ])
      },
    local.tags
  )
}

# Creates the Secret Manager entry
resource "aws_secretsmanager_secret_version" "msk_secret" {
  count = var.enabled && var.client_sasl_scram_enabled ? 1 : 0
  secret_id     = aws_secretsmanager_secret.msk_secret[0].id
  secret_string  = jsonencode({ username = "SECRET", password = "SECRET" })
}

resource "aws_msk_scram_secret_association" "default" {
  count = var.enabled && var.client_sasl_scram_enabled ? 1 : 0

  cluster_arn     = aws_msk_cluster.default[0].arn
  secret_arn_list = [aws_secretsmanager_secret.msk_secret[0].arn]
}