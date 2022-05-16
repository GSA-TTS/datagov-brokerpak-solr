

resource "aws_efs_file_system" "solr-data" {
  creation_token = "solr-data"

  tags = {
    Name = "SolrData"
  }
}

resource "aws_efs_access_point" "solr-data-access" {
  file_system_id = aws_efs_file_system.solr-data.id
}
