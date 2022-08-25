
resource "aws_sns_topic_subscription" "solr_memory_lambda_target" {
  topic_arn = aws_sns_topic.solr_memory_updates.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.solr_restarts
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_solr_restarts"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Effect": "Allow",
        "Sid": ""
      }
    ]
  }
  EOF
}

resource "aws_lambda_function" "solr_restarts" {
  function_name = "solr-${local.lb_name}-restarts"
  role          = aws_iam_role.iam_for_lambda.arn

  image_uri = "ghcr.io/gsa/catalog.data.gov.solr.restarts:latest"
  package_type = "Image"
}
