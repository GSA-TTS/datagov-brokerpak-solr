
resource "aws_efs_file_system" "solr-data" {
  creation_token = "solr-${local.id_64char}-data"

  # encryption-at-rest
  encrypted = true
  tags = {
    Name = "SolrData"
  }
}

resource "aws_efs_access_point" "solr-data-main" {
  file_system_id = aws_efs_file_system.solr-data.id
  root_directory {
    path = "/data1"
    creation_info {
      owner_gid   = "8983"
      owner_uid   = "8983"
      permissions = "755"
    }
  }
}

resource "aws_efs_mount_target" "all" {
  count          = length(module.vpc.public_subnets)
  file_system_id = aws_efs_file_system.solr-data.id
  subnet_id      = module.vpc.private_subnets[count.index]
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
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }
  egress {
    description = "GHCR Pull Images"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [for ip in data.dns_a_record_set.ghcr.addrs : "${ip}/32"]
  }
}

resource "aws_efs_file_system_policy" "policy" {
  file_system_id = aws_efs_file_system.solr-data.id

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
        ],
        "Condition": {
          "Bool": {
            "elasticfilesystem:AccessedViaMountTarget": "true"
          }
        }
      },
      {
        "Effect": "Deny",
        "Principal": {
          "AWS": "*"
        },
        "Action": "*",
        "Condition": {
          "Bool": {
            "aws:SecureTransport": "false"
          }
        }
      }
    ]
  }
  POLICY
}
