
locals {
  efs_mount_target_keys = range(0, var.solrFollowerCount * length(module.vpc.private_subnets))
}

resource "aws_efs_file_system" "solr-data-follower" {
  count          = var.disableEfsFollower ? 0 : var.solrFollowerCount
  creation_token = "solr-${local.id_64char}-follower-${count.index}-data"

  performance_mode                = var.efsPerformanceMode
  throughput_mode                 = "provisioned"
  provisioned_throughput_in_mibps = var.efsProvisionedThroughputFollower

  # encryption-at-rest
  encrypted  = true
  kms_key_id = aws_kms_key.solr-data-key[0].arn
  tags = {
    Name = "SolrData-${var.instance_name}-follower-${count.index}"
  }
}

resource "aws_efs_mount_target" "follower-all" {
  # Complex double-for loop based on https://www.daveperrett.com/articles/2021/08/19/nested-for-each-with-terraform/
  # For each EFS file system, we need to make a mount target in all subnets.
  for_each        = var.disableEfsFollower ? {} : { for i, entry in flatten([
      for efs in aws_efs_file_system.solr-data-follower : [
        for subnet in module.vpc.private_subnets : {
          efs_id = efs.id
          subnet_id = subnet
        }
      ]
    ]) : "${local.efs_mount_target_keys[i]}" => entry }

  file_system_id  = each.value.efs_id
  subnet_id       = each.value.subnet_id
  security_groups = [module.vpc.default_security_group_id, aws_security_group.solr-ecs-efs-ingress.id]

  depends_on = [
    aws_efs_file_system.solr-data-follower,
    module.vpc.private_subnets
  ]
}

resource "aws_efs_file_system_policy" "follower-policy" {
  count          = var.disableEfsFollower ? 0 : var.solrFollowerCount
  file_system_id = aws_efs_file_system.solr-data-follower[count.index].id

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

resource "aws_efs_backup_policy" "solr-data-follower-backup" {
  count          = var.disableEfsFollower ? 0 : var.solrFollowerCount
  file_system_id = aws_efs_file_system.solr-data-follower[count.index].id

  backup_policy {
    status = "ENABLED"
  }
}
