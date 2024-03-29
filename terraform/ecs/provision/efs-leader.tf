
resource "aws_kms_key" "solr-data-key" {
  count                   = var.disableEfs ? 0 : 1
  description             = "Solr Data Key (${var.instance_name}"
  deletion_window_in_days = 7
  policy = jsonencode({
    Statement = [
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Resource = "*"
        Sid      = "IAM User Permissions"
      }
    ]
    Version = "2012-10-17"
  })
}

resource "aws_efs_file_system" "solr-data" {
  count          = var.disableEfs ? 0 : 1
  creation_token = "solr-${local.id_64char}-data"

  performance_mode                = var.efsPerformanceMode
  throughput_mode                 = "provisioned"
  provisioned_throughput_in_mibps = var.efsProvisionedThroughput

  # encryption-at-rest
  encrypted  = true
  kms_key_id = aws_kms_key.solr-data-key[count.index].arn
  tags = {
    Name = "SolrData-${var.instance_name}"
  }
}

resource "aws_efs_mount_target" "all" {
  count           = var.disableEfs ? 0 : length(module.vpc.public_subnets)
  file_system_id  = aws_efs_file_system.solr-data[0].id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [module.vpc.default_security_group_id, aws_security_group.solr-ecs-efs-ingress.id]
}

resource "aws_security_group" "solr-ecs-efs-ingress" {
  name        = "solr-${var.instance_name}-service-sg"
  description = "EFS to talk to ECS Service"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Everything from EFS (well, mostly)"
    from_port   = 80
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
  egress {
    description = "Well... not sure."
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

resource "aws_efs_file_system_policy" "policy" {
  count          = var.disableEfs ? 0 : 1
  file_system_id = aws_efs_file_system.solr-data[count.index].id

  # encryption-in-transit
  policy = <<-POLICY
  {
    "Version": "2012-10-17",
    "Id": "efs-policy",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": "*"
        },
        "Action": [
          "elasticfilesystem:ClientRootAccess",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientMount"
        ]
      }
    ]
  }
  POLICY
}

resource "aws_efs_backup_policy" "solr-data-backup" {
  count          = var.disableEfs ? 0 : 1
  file_system_id = aws_efs_file_system.solr-data[count.index].id

  backup_policy {
    status = "ENABLED"
  }
}
