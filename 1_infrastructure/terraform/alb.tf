## Load Balancer Resource
resource "aws_lb" "ecs_alb" {
  name                       = "${var.app_name}-alb"
  internal                   = var.internal_alb
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.ecs_alb_sg.id]
  subnets                    = var.internal_alb ? [for subnet in data.aws_subnet.ecs_private_subnets_ids : subnet.id] : [for subnet in data.aws_subnet.ecs_public_subnets_ids : subnet.id]
  idle_timeout               = 60
  ip_address_type            = "ipv4"
  enable_deletion_protection = false

  access_logs {
    bucket  = var.elb_logs_s3_bucket != null ? var.elb_logs_s3_bucket : null
    prefix  = var.elb_logs_s3_bucket_prefix
    enabled = var.elb_logs_s3_bucket != null ? true : false
  }

  tags = {
    Name = "${var.app_name}-alb"
  }

  depends_on = [
    aws_security_group.ecs_alb_sg
  ]
}

output "ecs_alb_arn" {
  value = aws_lb.ecs_alb.arn
}

output "ecs_alb_dns_name" {
  value = aws_lb.ecs_alb.dns_name
}

## Target Group Resource
resource "aws_lb_target_group" "ecs_alb_tg" {
  name                 = "${var.app_name}-tg"
  port                 = 80
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = data.aws_vpc.main_vpc.id
  deregistration_delay = 60

  health_check {
    healthy_threshold   = 5
    unhealthy_threshold = 2
    interval            = 30
    matcher             = "200-499"
    path                = var.tg_health_check
    port                = length(var.health_check_port) > 0 ? var.health_check_port : "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
  }

  tags = {
    Name = "${var.app_name}-tg"
  }
}

output "ecs_alb_tg_arn" {
  value = aws_lb_target_group.ecs_alb_tg.arn
}

## ALB Listener Resource
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.ecs_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.external_edge_zones_acm.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ecs_alb_tg.arn
  }

  depends_on = [
    aws_lb_target_group.ecs_alb_tg
  ]
}

## R53 DNS Record
resource "aws_route53_record" "ecs_alb_r53_dns_internal" {
  count   = var.create_record && var.internal_alb ? 1 : 0
  zone_id = data.aws_route53_zone.internal_r53_hz.zone_id
  name    = var.r53_dns_name
  type    = "CNAME"
  ttl     = "60"
  records = [aws_lb.ecs_alb.dns_name]
}

resource "aws_route53_record" "ecs_alb_r53_dns_external" {
  count   = var.create_record && var.external_service || var.internal_alb ? 1 : 0
  zone_id = data.aws_route53_zone.external_r53_hz.zone_id
  name    = var.internal_alb ? "${var.r53_dns_name}.internal" : var.r53_dns_name
  type    = "CNAME"
  ttl     = "60"
  records = [aws_lb.ecs_alb.dns_name]
}

output "ecs_alb_r53_dns_fqdn_internal" {
  value = var.create_record && var.internal_alb ? aws_route53_record.ecs_alb_r53_dns_internal.*.fqdn : null
}

output "ecs_alb_r53_dns_fqdn_external" {
  value = var.create_record && var.external_service || var.internal_alb ? aws_route53_record.ecs_alb_r53_dns_external.*.fqdn : null
}