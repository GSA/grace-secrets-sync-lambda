# Hub role and policies
data "aws_iam_policy_document" "hub_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role" "hub_role" {
  count              = var.is_hub ? 1 : 0
  name               = local.app_name
  description        = "Role is used by ${local.app_name}"
  assume_role_policy = data.aws_iam_policy_document.hub_role.json
}

data "aws_iam_policy_document" "hub_policy" {
  count = var.is_hub ? 1 : 0
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [aws_kms_key.lambda[0].arn]
  }
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = ["arn:aws:secretsmanager:${var.region}:${local.account_id}:secret:${var.prefix}*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecrets"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:CreateLogGroup"
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = [
      "arn:aws:iam::${var.org_account_id}:role/${var.org_account_role_name}",
      "arn:aws:iam::*:role/${var.spoke_account_role_name}"
    ]
  }
}

resource "aws_iam_policy" "hub_policy" {
  count       = var.is_hub ? 1 : 0
  name        = local.app_name
  description = "Policy to allow lambda permissions for ${local.app_name}"
  policy      = data.aws_iam_policy_document.hub_policy[0].json
}

resource "aws_iam_role_policy_attachment" "hub_policy" {
  count      = var.is_hub ? 1 : 0
  role       = aws_iam_role.hub_role[0].name
  policy_arn = aws_iam_policy.hub_policy[0].arn
}




# Spoke role and policies

data "aws_iam_policy_document" "spoke_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.hub_account_id}:role/${local.app_name}"
      ]
    }
  }
}

resource "aws_iam_role" "spoke_role" {
  name               = var.spoke_account_role_name
  description        = "Role is used by ${local.app_name}"
  assume_role_policy = data.aws_iam_policy_document.spoke_role.json
}

data "aws_iam_policy_document" "spoke_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = [
      aws_kms_key.spoke_kms[0].arn
    ]
  }
  # https://docs.aws.amazon.com/secretsmanager/latest/userguide/reference_iam-permissions.html
  # 
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = ["arn:aws:secretsmanager:${var.region}:${local.account_id}:secret:*"]
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "secretsmanager:KmsKeyId"

      values = [
        aws_kms_key.spoke_kms.id
      ]
    }
  }
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:ListSecrets",
      "secretsmanager:CreateSecret",
      "secretsmanager:UpdateSecret",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "spoke_policy" {
  name        = var.spoke_account_role_name
  description = "Policy to allow lambda permissions for ${local.app_name}"
  policy      = data.aws_iam_policy_document.spoke_policy.json
}

resource "aws_iam_role_policy_attachment" "spoke_policy" {
  role       = aws_iam_role.spoke_role.name
  policy_arn = aws_iam_policy.spoke_policy.arn
}


