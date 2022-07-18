resource "random_uuid" "username" {}
resource "random_password" "password" {
  length  = 16
  special = false
  #  override_special = "_%@"
}

locals {
  solr_url = "${local.lb_name}.${aws_service_discovery_private_dns_namespace.solr.name}"
  solr_follower_urls = [for follower in range(0, var.solrFollowerCount) :
    "${local.lb_name}-follower-${follower}.${aws_service_discovery_private_dns_namespace.solr.name}"
  ]
  create_user_json = <<-EOF
    {
      "set-user": {
        "${random_uuid.username.result}":"${random_password.password.result}"
      }
    }
  EOF

  delete_user_json = <<-EOF
    {
      "delete-user": ["catalog"]
    }
  EOF

  set_role_json = <<-EOF
    {
      "set-user-role": {
        "${random_uuid.username.result}": ["admin"]
      }
    }
  EOF

  clear_role_json = <<-EOF
    {
      "set-user-role": {
        "catalog": null
      }
    }
  EOF
}

resource "aws_ecs_task_definition" "solr-admin-init" {
  family                   = "solr-${var.instance_name}-admin-init-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  task_role_arn            = aws_iam_role.solr-task-execution.arn
  execution_role_arn       = aws_iam_role.solr-task-execution.arn
  container_definitions = jsonencode([
    {
      name      = "solr-admin-init"
      image     = "${var.solrImageRepo}:8-efs-dns-root"
      cpu       = 256
      memory    = 512
      essential = true
      command = ["/bin/bash", "-c", join(" ", [
        "solr_ip=$(nslookup ${local.solr_url} | awk '/^Address: / { print $2 }');",
        "echo $solr_ip;",
        "curl -v -L -w \"%%{http_code}\n\" --user 'catalog:Bleeding-Edge' 'http://solr.null/solr/admin/authentication' --connect-to solr.null:80:$solr_ip:8983 -H 'Content-type:application/json' --data '${local.create_user_json}';",
        "curl -v -L -w \"%%{http_code}\n\" --user 'catalog:Bleeding-Edge' 'http://solr.null/solr/admin/authorization' --connect-to solr.null:80:$solr_ip:8983 -H 'Content-type:application/json' --data '${local.set_role_json}';",
        "curl -v -L -w \"%%{http_code}\n\" --user '${random_uuid.username.result}:${random_password.password.result}' 'http://solr.null/solr/admin/authorization' --connect-to solr.null:80:$solr_ip:8983 -H 'Content-type:application/json' --data '${local.clear_role_json}';",
        "curl -v -L -w \"%%{http_code}\n\" --user '${random_uuid.username.result}:${random_password.password.result}' 'http://solr.null/solr/admin/authentication' --connect-to solr.null:80:$solr_ip:8983 -H 'Content-type:application/json' --data '${local.delete_user_json}';",

        "solr_follower_urls=(${join(" ", local.solr_follower_urls)});",
        "for solr_follower_url in $${solr_follower_urls[@]}; do",
        "solr_ip=$(nslookup $solr_follower_url | awk '/^Address: / { print $2 }');",
        "echo $solr_ip;",
        "curl -v -L -w \"%%{http_code}\n\" --user 'catalog:Bleeding-Edge' 'http://solr.null/solr/admin/authentication' --connect-to solr.null:80:$solr_ip:8983 -H 'Content-type:application/json' --data '${local.create_user_json}';",
        "curl -v -L -w \"%%{http_code}\n\" --user 'catalog:Bleeding-Edge' 'http://solr.null/solr/admin/authorization' --connect-to solr.null:80:$solr_ip:8983 -H 'Content-type:application/json' --data '${local.set_role_json}';",
        "curl -v -L -w \"%%{http_code}\n\" --user '${random_uuid.username.result}:${random_password.password.result}' 'http://solr.null/solr/admin/authorization' --connect-to solr.null:80:$solr_ip:8983 -H 'Content-type:application/json' --data '${local.clear_role_json}';",
        "curl -v -L -w \"%%{http_code}\n\" --user '${random_uuid.username.result}:${random_password.password.result}' 'http://solr.null/solr/admin/authentication' --connect-to solr.null:80:$solr_ip:8983 -H 'Content-type:application/json' --data '${local.delete_user_json}';",
        "done;",
        "sleep infinity"
      ])]

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

resource "aws_ecs_service" "solr-init" {
  name                  = "solr-init-${var.instance_name}"
  cluster               = aws_ecs_cluster.solr-cluster.id
  task_definition       = aws_ecs_task_definition.solr-admin-init.arn
  desired_count         = 1
  launch_type           = "FARGATE"
  platform_version      = "1.4.0"
  wait_for_steady_state = true

  network_configuration {
    security_groups  = [module.vpc.default_security_group_id, aws_security_group.solr-ecs-efs-ingress.id]
    subnets          = module.vpc.private_subnets
    assign_public_ip = false
  }

  depends_on = [
    aws_ecs_service.solr
  ]
}
