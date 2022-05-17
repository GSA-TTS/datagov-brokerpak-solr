
resource "aws_kms_key" "ecs-log-key" {
  description             = "ecs log key"
  deletion_window_in_days = 7
}

resource "aws_cloudwatch_log_group" "ecs-logs" {
  name = "ecs-logs-solr"
}
