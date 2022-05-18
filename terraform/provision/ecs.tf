
data "aws_caller_identity" "current" {}

resource "aws_ecs_cluster" "solr-cluster" {
  name = "solr-${var.instance_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      kms_key_id = aws_kms_key.ecs-log-key.arn
      logging    = "OVERRIDE"

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.ecs-logs.name
      }
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "fargate" {
  cluster_name = aws_ecs_cluster.solr-cluster.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_ecs_task_definition" "solr" {
  family                   = "solr-${var.instance_name}-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 2048
  memory                   = 14336
  task_role_arn            = aws_iam_role.solr-task-execution.arn
  execution_role_arn       = aws_iam_role.solr-task-execution.arn
  container_definitions    = jsonencode([
    {
      name      = "solr"
      image     = "solr:8.11"
      cpu       = 2048
      memory    = 14336
      essential = true
      # command   = ["wget -o start.sh", "https://gist.githubusercontent.com/FuhuXia/91cac09b23ef29e5f219ba83df8b808e/raw/76de04dd7edf0faef2c04d8a8bbd51ee2cef237f/solr-setup-for-catalog.sh", "&&", "./start.sh"]
      portMappings = [
        {
          containerPort = 8983
          hostPort      = 8983
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs-logs.name,
          awslogs-region        = "us-west-2",
          awslogs-stream-prefix = "application"
        }
      }
      mountPoints = [
        {
          containerPath = "/var/solr/data",
          sourceVolume  = "solr-${var.instance_name}-data",
          readOnly      = false
        }
      ]
    },
  ])

  volume {
    name = "solr-${var.instance_name}-data"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.solr-data.id
      root_directory          = "/"
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2049
      authorization_config {
        access_point_id = aws_efs_access_point.solr-data-ap.id
        iam             = "ENABLED"
      }
    }
  }
}

resource "aws_ecs_service" "solr" {
  name            = "solr-${var.instance_name}"
  cluster         = aws_ecs_cluster.solr-cluster.id
  task_definition = aws_ecs_task_definition.solr.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  # iam_role        = aws_iam_role.solr.arn

  network_configuration {
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.solr-target.id
    container_name   = "solr"
    container_port   = 8983
  }
}
