
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
        "sed -i 's/{region}/${var.region}/g' /etc/amazon/efs/efs-utils.conf;",
        "printf \"\n${aws_efs_file_system.solr-data.id}:/data1 /var/solr/data efs tls,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,_netdev 0 0\n\" >> /etc/fstab;",
        "mount -t efs -o tls,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.solr-data.id}:/data1 /var/solr/data;",
        "cd /tmp; /usr/bin/wget https://gist.githubusercontent.com/nickumia-reisys/18544d2c6aad4160293bda1fec6ead7f/raw/bf668a33a1e3ac2c20342389ab9c8cb6cadeed8b/solr_setup.sh; /bin/bash solr_setup.sh;",
        "cd -; su -c \"",
        "init-var-solr; precreate-core ckan /tmp/ckan_config; chown -R 8983:8983 /var/solr/data; solr-fg -m 12g\" -m solr"
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
  task_definition       = aws_ecs_task_definition.solr.arn
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
    registry_arn = aws_service_discovery_service.solr.arn
    container_name = "solr"
    # container_port = 8983
  }

  depends_on = [
    aws_efs_mount_target.all,
    aws_efs_file_system.solr-data
  ]
}
