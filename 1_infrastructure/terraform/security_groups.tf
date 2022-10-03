locals {
  sg_settings = [
    {
      port        = 80,
      description = "Allow HTTP"
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 443,
      description = "Allow HTTPS"
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 9102,
      description = "Allow HealthCheck Port"
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 6379,
      description = "Allow Redis"
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 0
      description = "all ports open for Vulnerability scanning"
      protocol    = "-1"
      cidr_blocks = ["10.50.16.7/32"]
    }
  ]
}

## ECS Load Balancer Security Group
resource "aws_security_group" "ecs_alb_sg" {
  name        = "${var.app_name}-${local.environment}-alb-sg"
  description = "Load balancer security group for ${var.app_name}"
  vpc_id      = data.aws_vpc.main_vpc.id

   dynamic "ingress" {
    for_each = local.sg_settings
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-${local.environment}-alb-sg"
  }
}

output "ecs_alb_sg_id" {
  value = aws_security_group.ecs_alb_sg.id
}

## ECS Service Security Group
resource "aws_security_group" "ecs_service_sg" {
  name        = "${var.app_name}-${local.environment}-ecs-service-sg"
  description = "ECS Service security group for ${var.app_name} to route traffic to the container running inside the task definition"
  vpc_id      = data.aws_vpc.main_vpc.id

  dynamic "ingress" {
    for_each = local.sg_settings
    content {
      description = ingress.value.description
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  ingress {
    description     = "Allow ${var.app_name} LB"
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.ecs_alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.app_name}-${local.environment}-ecs-service-sg"
  }
}

output "ecs_service_sg_id" {
  value = aws_security_group.ecs_service_sg.id
}