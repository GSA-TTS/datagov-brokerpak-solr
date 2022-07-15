
locals {
  solrFollowerMemInG = floor(var.solrFollowerMem / 1000)
}

resource "aws_ecs_task_definition" "solr-follower" {
  family                   = "solr-follower-${var.instance_name}-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.solrFollowerCpu
  memory                   = var.solrFollowerMem
  task_role_arn            = aws_iam_role.solr-task-execution.arn
  execution_role_arn       = aws_iam_role.solr-task-execution.arn
  ephemeral_storage {
    size_in_gib = var.solrFollowerDiskSize
  }

  container_definitions = jsonencode([
    {
      name      = "solr"
      image     = "${var.solrImageRepo}:${var.solrImageTag}"
      cpu       = var.solrFollowerCpu
      memory    = var.solrFollowerMem
      essential = true
      command = ["/bin/bash", "-c", join(" ", [
        "df -h;",
        "cd /tmp; /usr/bin/wget -O solr_setup.sh ${var.setupLink}; /bin/bash solr_setup.sh;",
        "chown -R 8983:8983 /var/solr/data;",
        "cd -; su -c \"",
        "init-var-solr; precreate-core ckan /tmp/ckan_config; chown -R 8983:8983 /var/solr/data; solr-fg -m ${local.solrFollowerMemInG}g\" -m solr"
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
          awslogs-stream-prefix = "solr-follower"
        }
      }
    },
  ])
}

resource "aws_ecs_service" "solr-follower" {
  count                 = var.solrFollowerCount
  name                  = "solr-follower-${count.index}-${var.instance_name}"
  cluster               = aws_ecs_cluster.solr-cluster.id
  task_definition       = aws_ecs_task_definition.solr-follower.arn
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
    container_name = "solr-follower-${count.index}"
    # container_port = 8983
  }
}
