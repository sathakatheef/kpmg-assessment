resource "aws_secretsmanager_secret" "private_reg_secret" {
  name                    = "${var.app_name}-${var.priavte_registry_name}-secret"
  description             = "Private docker registry Authentication secrets for ${var.priavte_registry_name}"
  kms_key_id              = aws_kms_key.secrets_key.arn
  recovery_window_in_days = 0

  tags = {
    Name = "${var.app_name}-${var.priavte_registry_name}-secret"
  }

  depends_on = [
    aws_kms_key.secrets_key
  ]
}

resource "aws_secretsmanager_secret_policy" "private_reg_secret_policy" {
  secret_arn = aws_secretsmanager_secret.private_reg_secret.arn

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowAccessToTheSecret",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "${aws_secretsmanager_secret.private_reg_secret.arn}"
    },
    {
      "Sid": "AllowSecretToAccessKMSKey",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      "Action": "*",
      "Resource": "*"
    }
  ]
}
POLICY
}

resource "aws_secretsmanager_secret_version" "private_reg_secret" {
  secret_id     = aws_secretsmanager_secret.private_reg_secret.id
  secret_string = jsonencode({
  "username": "${var.private_regisrty_username}",
  "password": "${var.private_registry_passwd}"
})
}

output "private_reg_secret_id" {
  value = aws_secretsmanager_secret.private_reg_secret.id
}