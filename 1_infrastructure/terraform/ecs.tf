## ECS Task Definition's CloudWatch LogGroup
resource "aws_cloudwatch_log_group" "ecs_task_log_group" {
  name = "/ecs/${var.app_name}-${local.environment}"
  tags = {
    Name = "/ecs/${var.app_name}-${local.environment}"
  }
}

## ECS Task Definition
resource "aws_ecs_task_definition" "ecs_task" {
  family                   = "${var.app_name}-${local.environment}"
  task_role_arn            = var.task_role_arn == "" ? aws_iam_role.ecs_task_role.arn : var.task_role_arn
  execution_role_arn       = aws_iam_role.ecs_task_role.arn
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  requires_compatibilities = ["FARGATE"]
  container_definitions    = <<TASK_DEFINITION
[
  {
    "cpu": ${var.container_cpu},
    "memory": ${var.container_memory_limit},
    "memoryReservation": ${var.container_memory_request},
    "essential": true,
    "image": "${var.container_image}",
    "name": "${var.container_name}",
    "logConfiguration": {
      "logDriver": "awslogs",
      "secretOptions": null,
      "options": {
          "awslogs-group": "/ecs/${var.app_name}-${local.environment}",
          "awslogs-region": "ap-southeast-2",
          "awslogs-stream-prefix": "ecs"
      }
    },
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80,
        "protocol":"tcp"
      }
    ],
    "repositoryCredentials": {
      "credentialsParameter": "${aws_secretsmanager_secret.private_reg_secret.arn}"
    },
    "secrets": [],
    "environment": "${length(var.task_env_variables) ? jsonencode(var.task_env_variables) : null}"
  }
]
TASK_DEFINITION

  runtime_platform {
    operating_system_family = "WINDOWS_SERVER_2019_CORE"
    cpu_architecture        = "X86_64"
  }

  tags = {
    Name = "${var.app_name}-${local.environment}"
  }

  depends_on = [
    aws_iam_role.ecs_task_role,
    aws_secretsmanager_secret.private_reg_secret
  ]
}

## ECS Task Service
resource "aws_ecs_service" "ecs_service" {
  name                               = "${var.app_name}-${local.environment}"
  cluster                            = var.ecs_cluster_arn
  task_definition                    = aws_ecs_task_definition.ecs_task.arn
  desired_count                      = var.task_desired_count
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  enable_ecs_managed_tags            = "true"
  enable_execute_command             = var.enable_execute_command
  force_new_deployment               = "true"
  health_check_grace_period_seconds  = 0
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  scheduling_strategy                = "REPLICA"
  wait_for_steady_state              = var.wait_for_ecs_service_steady_state

  network_configuration {
    subnets          = [for subnet in data.aws_subnet.ecs_private_subnets_ids : subnet.id]
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = "false"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_alb_tg.arn
    container_name   = var.container_name
    container_port   = 80
  }

  tags = {
    Name = "${var.app_name}-${local.environment}"
  }

  ## Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [desired_count]
  }

  timeouts {
    delete = "60m"
  }

  depends_on = [
    aws_ecs_task_definition.ecs_task,
    aws_lb_target_group.ecs_alb_tg
  ]
}

## ECS Service Autoscaling Resources
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count               = !var.need_service_auto_scaling ? 0 : 1
  alarm_name          = "ecs-service-${var.app_name}-${local.environment}-cpu-high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Maximum"
  threshold           = var.cpu_high_threshold
  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.ecs_service.name
  }
  alarm_actions = [aws_appautoscaling_policy.scale_up_policy[count.index].arn]

  tags = {
    Name = "ecs-service-${var.app_name}-${local.environment}-cpu-high"
  }
}


resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  count               = !var.need_service_auto_scaling ? 0 : 1
  alarm_name          = "ecs-service-${var.app_name}-${local.environment}-cpu-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "120"
  statistic           = "Average"
  threshold           = var.cpu_low_threshold
  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = aws_ecs_service.ecs_service.name
  }
  alarm_actions = [aws_appautoscaling_policy.scale_down_policy[count.index].arn]

  tags = {
    Name = "ecs-service-${var.app_name}-${local.environment}-cpu-low"
  }
}

resource "aws_appautoscaling_policy" "scale_up_policy" {
  count              = !var.need_service_auto_scaling ? 0 : 1
  name               = "ecs-service-${var.app_name}-${local.environment}-scale-up-policy"
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"
    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }

  depends_on = [
    aws_appautoscaling_target.scale_target
  ]
}

resource "aws_appautoscaling_policy" "scale_down_policy" {
  count              = !var.need_service_auto_scaling ? 0 : 1
  name               = "ecs-service-${var.app_name}-${local.environment}-scale-down-policy"
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"
    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }

  depends_on = [
    aws_appautoscaling_target.scale_target
  ]
}

resource "aws_appautoscaling_target" "scale_target" {
  count              = !var.need_service_auto_scaling ? 0 : 1
  service_namespace  = "ecs"
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.scale_target_min_capacity
  max_capacity       = var.scale_target_max_capacity
}