#tfsec:ignore:AWS099
data "aws_iam_policy_document" "lambda" {
  count = var.is_hub ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.hub_role[0].arn]
    }
  }
}

resource "aws_kms_key" "lambda" {
  count                   = var.is_hub ? 1 : 0
  description             = "Key used for ${local.app_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.lambda[0].json

  depends_on = [aws_iam_role.hub_role[0]]
}

resource "aws_kms_alias" "lambda" {
  count         = var.is_hub ? 1 : 0
  name          = "alias/${local.app_name}"
  target_key_id = aws_kms_key.lambda[0].key_id
}

#tfsec:ignore:AWS099
data "aws_iam_policy_document" "spoke_kms" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
    principals {
      type = "AWS"
      identifiers = [
        aws_iam_role.spoke_role.arn,
        "arn:aws:iam::${local.account_id}:root"
      ]
    }
  }
}

resource "aws_kms_key" "spoke_kms" {
  description             = "Key used for ${local.app_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.spoke_kms.json

  depends_on = [aws_iam_role.spoke_role]
}

resource "aws_kms_alias" "spoke_kms" {
  name          = "alias/${var.spoke_account_role_name}"
  target_key_id = aws_kms_key.spoke_kms.key_id
}