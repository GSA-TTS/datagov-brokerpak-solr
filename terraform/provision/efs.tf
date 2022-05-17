

resource "aws_efs_file_system" "solr-data" {
  creation_token = "solr-data"

  tags = {
    Name = "SolrData"
  }
}

resource "aws_efs_access_point" "solr-data-access" {
  file_system_id = aws_efs_file_system.solr-data.id
}

resource "aws_efs_mount_target" "all" {
  count = length(module.vpc.public_subnets)
  file_system_id = aws_efs_file_system.solr-data.id
  subnet_id      = module.vpc.public_subnets[count.index]
}
