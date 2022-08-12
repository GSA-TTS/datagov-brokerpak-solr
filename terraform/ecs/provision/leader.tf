
locals {
  solrMemInG = floor(var.solrMem / 1000)
}

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
  count                    = var.disableEfs ? 0 : 1
  family                   = "solr-${var.instance_name}-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.solrCpu
  memory                   = var.solrMem
  task_role_arn            = aws_iam_role.solr-task-execution.arn
  execution_role_arn       = aws_iam_role.solr-task-execution.arn
  container_definitions = jsonencode([
    {
      name      = "solr"
      image     = "${var.solrImageRepo}:${var.solrImageTag}"
      cpu       = var.solrCpu
      memory    = var.solrMem
      essential = true
      command = ["/bin/bash", "-c", join(" ", [
        "set -e;",
        "cd /tmp; /usr/bin/wget -O solr_setup.sh ${var.setupLink}; /bin/bash solr_setup.sh;",
        "rm -rf /tmp/ckan_config/solrconfig_follower.xml;",
        "chown -R 8983:8983 /var/solr/data;",
        "cd -; su -c \"",
        "init-var-solr; precreate-core ckan /tmp/ckan_config; chown -R 8983:8983 /var/solr/data; solr-fg -m ${local.solrMemInG}g -Dsolr.lock.type=simple\" -m solr"
      ])]

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
      file_system_id     = aws_efs_file_system.solr-data[count.index].id
      transit_encryption = "DISABLED"
    }
  }
}

resource "aws_ecs_task_definition" "solr-no-efs" {
  count                    = var.disableEfs ? 1 : 0
  family                   = "solr-${var.instance_name}-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.solrCpu
  memory                   = var.solrMem
  task_role_arn            = aws_iam_role.solr-task-execution.arn
  execution_role_arn       = aws_iam_role.solr-task-execution.arn
  ephemeral_storage {
    size_in_gib = 50
  }
  container_definitions = jsonencode([
    {
      name      = "solr"
      image     = "${var.solrImageRepo}:${var.solrImageTag}"
      cpu       = var.solrCpu
      memory    = var.solrMem
      essential = true
      command = ["/bin/bash", "-c", join(" ", [
        "df -h;",
        "cd /tmp; /usr/bin/wget -O solr_setup.sh ${var.setupLink}; /bin/bash solr_setup.sh;",
        "rm -rf /tmp/ckan_config/solrconfig_follower.xml;",
        "chown -R 8983:8983 /var/solr/data;",
        "cd -; su -c \"",
        "init-var-solr; precreate-core ckan /tmp/ckan_config; chown -R 8983:8983 /var/solr/data; solr-fg -m ${local.solrMemInG}g\" -m solr"
      ])]

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
    },
  ])
}

resource "aws_ecs_service" "solr" {
  name                  = "solr-${var.instance_name}"
  cluster               = aws_ecs_cluster.solr-cluster.id
  task_definition       = var.disableEfs ? aws_ecs_task_definition.solr-no-efs[0].arn : aws_ecs_task_definition.solr[0].arn
  desired_count         = 1
  launch_type           = "FARGATE"
  platform_version      = "1.4.0"
  wait_for_steady_state = true

  network_configuration {
    security_groups  = [module.vpc.default_security_group_id, aws_security_group.solr-ecs-efs-ingress.id]
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.solr-target.id
    container_name   = "solr"
    container_port   = 8983
  }
  service_registries {
    registry_arn   = aws_service_discovery_service.solr.arn
    container_name = "solr"
    # container_port = 8983
  }

  depends_on = [
    aws_efs_mount_target.all,
    aws_efs_file_system.solr-data
  ]
}
