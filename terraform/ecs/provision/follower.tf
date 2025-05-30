
locals {
  solrFollowerMemInG = floor(var.solrFollowerMem / 1000)
}

resource "aws_ecs_task_definition" "solr-follower-no-efs" {
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
        "cd /tmp; /usr/bin/wget -O solr_setup.sh ${var.setupFollowerLink}; /bin/bash solr_setup.sh;",
        "mv /tmp/ckan_config/solrconfig_follower.xml /tmp/ckan_config/solrconfig.xml;",
        "sed -i 's/SOLR_REPLICATION_LEADER_URL/https:\\/\\/${local.leader_domain}:443\\/solr\\/ckan\\/replication/g' /tmp/ckan_config/solrconfig.xml;",
        "sed -i 's/SOLR_REPLICATION_LEADER_USER/${random_uuid.username.result}/g' /tmp/ckan_config/solrconfig.xml;",
        "sed -i 's/SOLR_REPLICATION_LEADER_PASSWORD/${random_password.password.result}/g' /tmp/ckan_config/solrconfig.xml;",
        "chown -R 8983:8983 /var/solr/data;",
        "cd -; su -c \"",
        "init-var-solr; precreate-core ckan /tmp/ckan_config; chown -R 8983:8983 /var/solr/data; solr-fg -m ${local.solrFollowerMemInG}g -Dsolr.disable.shardsWhitelist=true\" -m solr"
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

resource "aws_ecs_task_definition" "solr-follower" {
  count                    = var.disableEfsFollower ? 0 : var.solrFollowerCount
  family                   = "solr-follower-${count.index}-${var.instance_name}-service"
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
        "cd /tmp; /usr/bin/wget -O solr_setup.sh ${var.setupFollowerLink}; /bin/bash solr_setup.sh;",
        "mv /tmp/ckan_config/solrconfig_follower.xml /tmp/ckan_config/solrconfig.xml;",
        "sed -i 's/SOLR_REPLICATION_LEADER_URL/https:\\/\\/${local.leader_domain}:443\\/solr\\/ckan\\/replication/g' /tmp/ckan_config/solrconfig.xml;",
        "sed -i 's/SOLR_REPLICATION_LEADER_USER/${random_uuid.username.result}/g' /tmp/ckan_config/solrconfig.xml;",
        "sed -i 's/SOLR_REPLICATION_LEADER_PASSWORD/${random_password.password.result}/g' /tmp/ckan_config/solrconfig.xml;",
        "chown -R 8983:8983 /var/solr/data;",
        "cd -; su -c \"",
        "init-var-solr; precreate-core ckan /tmp/ckan_config; chown -R 8983:8983 /var/solr/data;",
        "[[ -f /var/solr/data/ckan/data/index/write.lock ]] && { ls -l /var/solr/data/ckan/data/index/write.lock; echo 'The lock file is back. exit to avoid conflict.'; exit 1;};",
        "solr-fg -m ${local.solrFollowerMemInG}g -Dsolr.lock.type=simple -Dsolr.disable.shardsWhitelist=true\" -m solr"
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
      file_system_id     = aws_efs_file_system.solr-data-follower[count.index].id
      transit_encryption = "DISABLED"
    }
  }
}


resource "aws_ecs_service" "solr-follower" {
  count                 = var.solrFollowerCount
  name                  = "solr-follower-${count.index}-${var.instance_name}"
  cluster               = aws_ecs_cluster.solr-cluster.id
  task_definition       = var.disableEfsFollower ? aws_ecs_task_definition.solr-follower-no-efs.arn : aws_ecs_task_definition.solr-follower[count.index].arn
  desired_count         = 1
  launch_type           = "FARGATE"
  platform_version      = "1.4.0"
  wait_for_steady_state = true

  network_configuration {
    security_groups  = [module.vpc.default_security_group_id, aws_security_group.solr-ecs-efs-ingress.id, aws_security_group.ecs_container_egress.id]
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.solr-follower-individual-target[count.index].id
    container_name   = "solr"
    container_port   = 8983
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.solr-follower-target[0].id
    container_name   = "solr"
    container_port   = 8983
  }
  service_registries {
    registry_arn   = aws_service_discovery_service.solr-follower[count.index].arn
    container_name = "solr-follower-${count.index}"
    # container_port = 8983
  }
}
