
variable "app_name" {}

variable "region" {}

variable "managed_policy_arn" { type = list(string) }

variable "tg_health_check" {}

variable "health_check_port" {}

variable "dns_suffix" {}

variable "priavte_registry_name" {}

variable "private_regisrty_username" {}

variable "private_registry_passwd" {}

variable "task_role_arn" {}

variable "task_cpu" { type = number }

variable "task_memory" { type = number }

variable "container_cpu" { type = number }

variable "container_memory_limit" { type = number }

variable "container_memory_request" { type = number }

variable "container_image" {}

variable "container_name" {}

variable "ecs_cluster_arn" {}

variable "task_desired_count" {}

variable "enable_execute_command" { type = bool }

variable "wait_for_ecs_service_steady_state" { type = bool }

variable "ecs_cluster_name" {}

variable "need_service_auto_scaling" { type = bool }  ## To enable or disable service auto scaling. Value must be either true or false.

variable "cpu_low_threshold" {}

variable "cpu_high_threshold" {}

variable "scale_target_min_capacity" {}

variable "scale_target_max_capacity" {}

variable "elb_logs_s3_bucket" {}

variable "elb_logs_s3_bucket_prefix" {}

variable "create_record" { type = bool }

variable "r53_dns_name" {}

variable "TEAM" {}

variable "ENVIRONMENT" {}

variable "CI_PROJECT_URL" {}