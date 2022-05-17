
data "aws_caller_identity" "current" {}

resource "aws_ecs_cluster" "solr-cluster" {
  name = "solr-cluster"
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
  family = "service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 2048
  memory                   = 14336
  container_definitions = jsonencode([
    {
      name      = "solr"
      image     = "solr:8.11"
      cpu       = 2048
      memory    = 14336
      essential = true
      portMappings = [
        {
          containerPort = 8983
          hostPort      = 8983
        }
      ]
      # mountPoints = [
      #   {
      #     containerPath = "/var/solr/data",
      #     sourceVolume = "solr-data"
      #   }
      # ]
    },
  ])

  # volume {
  #   name      = "solr-data"
  #   efs_volume_configuration {
  #     file_system_id          = aws_efs_file_system.solr-data.id
  #     root_directory          = "/"
  #     # transit_encryption      = "ENABLED"
  #     # transit_encryption_port = 2999
  #     # authorization_config {
  #     #   access_point_id = aws_efs_access_point.solr-data-access.id
  #     #   iam             = "ENABLED"
  #     # }
  #   }
  # }

  # placement_constraints {
  #   type       = "memberOf"
  #   expression = "attribute:ecs.availability-zone in [us-west-2a]"
  # }
}

resource "aws_ecs_service" "solr" {
  name            = "solr"
  cluster         = aws_ecs_cluster.solr-cluster.id
  task_definition = aws_ecs_task_definition.solr.arn
  desired_count   = 1
  launch_type = "FARGATE"
  # iam_role        = aws_iam_role.solr.arn

  network_configuration {
    subnets = module.vpc.public_subnets
    assign_public_ip = true
  }

  # placement_constraints {
  #   type       = "memberOf"
  #   expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  # }
}
