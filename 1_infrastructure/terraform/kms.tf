resource "aws_kms_key" "secrets_key" {
  description             = "KMS key used to encrypt and decrypt secrets in the secrets manager"
  deletion_window_in_days = 7
  enable_key_rotation     = "false"
  policy                  = data.aws_iam_policy_document.secrets_key_policy_document.json

  tags = {
    Name = "${var.app_name}-${var.priavte_registry_name}-secret-key"
  }
}

resource "aws_kms_alias" "secrets_key_alias" {
  name          = "alias/${var.app_name}-${var.priavte_registry_name}-secret-key"
  target_key_id = aws_kms_key.secrets_key.key_id
}

data "aws_iam_policy_document" "secrets_key_policy_document" {

  statement {
    sid = "Allow administration of the key"
    principals {
       type       = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions = [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion"
    ]
    resources = ["*"]
  }

  statement {
    sid = "Allow access through AWS Secrets Manager for all principals in the account that are authorized to use AWS Secrets Manager in the sydney region"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:GenerateDataKey*"
    ]
    principals {
       type       = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = ["secretsmanager.${var.region}.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values = ["${data.aws_caller_identity.current.account_id}"]
    }
    resources = ["*"]
  }

  statement {
    sid = "Allow direct access to key metadata to the account"
    actions = [
      "kms:Describe*",
      "kms:Get*",
      "kms:List*",
      "kms:RevokeGrant"
    ]
    principals {
       type       = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = ["*"]
  }
}

output "secrets_key_id" {
  value = aws_kms_key.secrets_key.key_id
}