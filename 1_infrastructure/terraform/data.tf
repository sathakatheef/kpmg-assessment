data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "policy_document" {

  statement {
    actions = [
      "kms:Decrypt",
      "secretsmanager:GetSecretValue",
      "ssm:GetParameters"
    ]
    resources = [
      "${aws_kms_key.secrets_key.arn}",
      "${aws_secretsmanager_secret.private_reg_secret.arn}"
    ]
  }

  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "ecs_task_assume_role_policy" {
  statement {
    sid     = "ECSTask"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

## Fetch VPC Id
data "aws_vpc" "main_vpc" {
  filter {
    name   = "tag:Name"
    values = ["*-main"]
  }
}

## Fetch ECS Subnet Ids
data "aws_subnet_ids" "ecs_private_subnets" {
  vpc_id = data.aws_vpc.main_vpc.id
  filter {
    name   = "tag:Name"
    values = ["ecs-private-*"]
  }
}

data "aws_subnet" "ecs_private_subnets_ids" {
  for_each = data.aws_subnet_ids.ecs_private_subnets.ids
  id       = each.value
}

data "aws_subnet_ids" "ecs_public_subnets" {
  vpc_id = data.aws_vpc.main_vpc.id
  filter {
    name   = "tag:Name"
    values = ["ecs-public-*"]
  }
}

data "aws_subnet" "ecs_public_subnets_ids" {
  for_each = data.aws_subnet_ids.ecs_public_subnets.ids
  id       = each.value
}

## Fetch ACM Certs
data "aws_acm_certificate" "internal_edge_zones_acm" {
  domain      = "*.internal.${var.ENVIRONMENT}.${var.dns_suffix}"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
  statuses    = ["ISSUED"]
}

data "aws_acm_certificate" "external_edge_zones_acm" {
  domain      = "*.${var.ENVIRONMENT}.${var.dns_suffix}"
  types       = ["AMAZON_ISSUED"]
  most_recent = true
  statuses    = ["ISSUED"]
}

## Fetch DNS hosted zone
data "aws_route53_zone" "internal_r53_hz" {
  name         = "internal.${var.ENVIRONMENT}.${var.dns_suffix}."
  private_zone = true
  vpc_id       = data.aws_vpc.main_vpc.id
}

data "aws_route53_zone" "external_r53_hz" {
  name         = "${var.ENVIRONMENT}.${var.dns_suffix}."
  private_zone = false
}