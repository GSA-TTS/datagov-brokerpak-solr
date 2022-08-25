
resource "aws_sns_topic" "solr_memory_updates" {
  name              = "solr-memory-topic"
  kms_master_key_id = "alias/aws/sns"
}

resource "aws_cloudwatch_metric_alarm" "solr-leader-oom" {
  alarm_name          = "Solr-MemoryThreshold"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  namespace           = "ECS/ContainerInsights"
  metric_name         = "MemoryUtilized"
  statistic           = "Average"
  period              = "60"
  threshold           = "25000"
  datapoints_to_alarm = "1"
  alarm_description   = "This metric monitors solr memory consumption"

  dimensions = {
    ClusterName = aws_ecs_cluster.solr-cluster.name
    ServiceName = aws_ecs_service.solr.name
  }

  alarm_actions = [aws_sns_topic.solr_memory_updates.arn]
  ok_actions    = [aws_sns_topic.solr_memory_updates.arn]

  insufficient_data_actions = []
}

resource "aws_cloudwatch_metric_alarm" "solr-follower-oom" {
  count               = var.solrFollowerCount + 1
  alarm_name          = "Solr-Follower-${count.index}-MemoryThreshold"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  namespace           = "ECS/ContainerInsights"
  metric_name         = "MemoryUtilized"
  statistic           = "Average"
  period              = "60"
  threshold           = "25000"
  datapoints_to_alarm = "1"
  alarm_description   = "This metric monitors solr memory consumption"

  dimensions = {
    ClusterName = aws_ecs_cluster.solr-cluster.name
    ServiceName = aws_ecs_service.solr-follower[count.index].name
  }

  alarm_actions = [aws_sns_topic.solr_memory_updates.arn]
  ok_actions    = [aws_sns_topic.solr_memory_updates.arn]

  insufficient_data_actions = []
}
