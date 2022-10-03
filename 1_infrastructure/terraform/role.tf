locals {
  environment      = "${terraform.workspace}"
}

## ECS Task Role
resource "aws_iam_role" "ecs_task_role" {
  name               = "ecs-taskrole-${var.app_name}-${local.environment}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json

  tags = {
    Name = "ecs-taskrole-${var.app_name}-${local.environment}"
  }

  depends_on = [
    aws_kms_key.secrets_key,
    aws_secretsmanager_secret.private_reg_secret
  ]
}

resource "aws_iam_policy" "ecs_task_role_policy" {
  name   = "ecs-taskrole-${var.app_name}-policy-${local.environment}"
  path   = "/"
  policy = data.aws_iam_policy_document.policy_document.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_role_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_managed_policy_attachment" {
  count      = length(var.managed_policy_arn)
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = var.managed_policy_arn[count.index]
}

output "ecs_task_role_arn" {
  value = aws_iam_role.ecs_task_role.arn
}