
resource "aws_iam_role" "solr" {
  name = "solr_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "solr-efs-ecs" {
  name       = "solr-efs-ecs-attachment"
  roles      = [aws_iam_role.solr.name]
  policy_arn = aws_iam_policy.ecs-solr-efs.arn
}

resource "aws_iam_policy" "ecs-solr-efs" {
  name        = "efs-policy"
  path        = "/"
  description = "Solr EFS ECS Policy"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
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
