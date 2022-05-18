
resource "aws_iam_role" "solr-task-execution" {
  name = "solr-${var.instance_name}-task_role"

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

# resource "aws_iam_policy_attachment" "solr-ecs-basic" {
#   name       = "solr-efs-ecs-attachment"
#   roles      = [aws_iam_role.solr-task-execution.name]
#   policy_arn = aws_iam_policy.ecs-basic.arn
# }

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

# resource "aws_iam_policy" "ecs-basic" {
#   name        = "ecs-basic-policy"
#   path        = "/"
#   description = "Allow solr to run on ecs"
# 
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#           "ec2:AttachNetworkInterface",
#           "ec2:CreateNetworkInterface",
#           "ec2:CreateNetworkInterfacePermission",
#           "ec2:DeleteNetworkInterface",
#           "ec2:DeleteNetworkInterfacePermission",
#           "ec2:Describe*",
#           "ec2:DetachNetworkInterface",
#         ]
#         Effect   = "Allow"
#         Resource = "*"
#       },
#     ]
#   })
# }

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
          "logs:PutLogEvents",
          "ecr:*",
          # "s3:*",
          # "efs:*"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}
