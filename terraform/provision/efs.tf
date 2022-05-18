
resource "aws_efs_file_system" "solr-data" {
  creation_token = "solr-${var.instance_name}-data"

  # encryption-at-rest
  encrypted = true
  tags = {
    Name = "SolrData"
  }
}

resource "aws_efs_access_point" "solr-data-ap" {
  file_system_id = aws_efs_file_system.solr-data.id
  # EFS needs to be mounted as root to be able to write-to/create files
  posix_user {
    gid = "0"
    uid = "0"
  }
}

resource "aws_efs_mount_target" "all" {
  count          = length(module.vpc.public_subnets)
  file_system_id = aws_efs_file_system.solr-data.id
  subnet_id      = module.vpc.public_subnets[count.index]
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
