resource "aws_kms_key" "kms" {
  count              = var.enabled ? 1 : 0
  description         = local.terraform_description
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.kms.json
  tags = merge({
    "Name" = join("-", [local.cluster_name, "kms-key"])
    },
    local.tags
  )
}

resource "aws_kms_alias" "kms" {
  count =  var.enabled ? var.kms_exist ? 0 : 1 : 0
  name          = "alias/${local.cluster_name}"
  target_key_id = aws_kms_key.kms[0].key_id
}

data "aws_iam_policy_document" "kms" {
  statement {
    sid    = "Enable IAM User Permissions, Root can control every thing"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow access for Key Administrators"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/AdminRole"]
    }
    actions = ["kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
    "kms:CancelKeyDeletion"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow use of the key"
    effect = "Allow"
    principals {
      type = "AWS"
      //TODO: Interpolation of arn to be done.
      identifiers = var.execution_role != "" ? ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.execution_role}"] : ["*"]
    }
    actions = ["kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:ListGrants",
    "kms:DescribeKey"]
    resources = ["arn:aws:kafka:data.aws_region.current.name:${data.aws_caller_identity.current.account_id}:cluster/${local.cluster_name}/*"]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["lambda.ap-southeast-2.amazonaws.com"]

    }
    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

}