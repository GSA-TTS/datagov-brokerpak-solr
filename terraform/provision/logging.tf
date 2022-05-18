
resource "aws_kms_key" "ecs-log-key" {
  description             = "ecs solr log key (${var.instance_name})"
  deletion_window_in_days = 7
}

resource "aws_cloudwatch_log_group" "ecs-logs" {
  name = "ecs-logs-solr-${var.instance_name}"
}
