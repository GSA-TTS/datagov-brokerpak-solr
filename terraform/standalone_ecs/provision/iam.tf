
locals {
  id_64char = substr(var.instance_name, 0, 54)
}

resource "aws_iam_role" "solr-task-execution" {
  name = "${local.id_64char}-task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "solr-efs-ecs" {
  name       = "solr-${var.instance_name}-efs-ecs-attachment"
  roles      = [aws_iam_role.solr-task-execution.name]
  policy_arn = aws_iam_policy.ecs-solr-efs.arn
}

resource "aws_iam_policy_attachment" "solr-ecs-execution-role" {
  name       = "solr-${var.instance_name}-ecs-execution-role-attachment"
  roles      = [aws_iam_role.solr-task-execution.name]
  policy_arn = aws_iam_policy.ecs-tasks.arn
}

resource "aws_iam_policy" "ecs-solr-efs" {
  name        = "solr-${var.instance_name}-efs-policy"
  path        = "/"
  description = "Allow ECS to talk to EFS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:elasticfilesystem:${var.region}:${data.aws_caller_identity.current.id}:file-system/${aws_efs_file_system.solr-data.id}"
      },
    ]
  })
}

resource "aws_iam_policy" "ecs-tasks" {
  name        = "solr-${var.instance_name}-ecs-tasks"
  path        = "/"
  description = "Allow solr task role to run on ecs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents",
          "ecr:*",
          # "s3:*",
          "efs:*",
          "elasticfilesystem:*",
          "ec2:AttachNetworkInterface",
          "ec2:CreateNetworkInterface",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DeleteNetworkInterface",
          "ec2:DeleteNetworkInterfacePermission",
          "ec2:Describe*",
          "ec2:DetachNetworkInterface",
          "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:Describe*",
          "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
          "elasticloadbalancing:RegisterTargets",
          "kms:*",
          "route53:ChangeResourceRecordSets",
          "route53:CreateHealthCheck",
          "route53:DeleteHealthCheck",
          "route53:Get*",
          "route53:List*",
          "route53:UpdateHealthCheck",
          "servicediscovery:DeregisterInstance",
          "servicediscovery:Get*",
          "servicediscovery:List*",
          "servicediscovery:RegisterInstance",
          "servicediscovery:UpdateInstanceCustomHealthStatus",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ssm:UpdateInstanceInformation"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "iam:CreateServiceLinkedRole"
        ],
        Resource  = "arn:aws:iam::*:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS*",
        Condition = { "StringLike" : { "iam:AWSServiceName" : "ecs.amazonaws.com" } }
      }
    ]
  })
}
