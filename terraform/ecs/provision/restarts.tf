
resource "aws_sns_topic_subscription" "solr_memory_lambda_target" {
  topic_arn = aws_sns_topic.solr_memory_updates.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.solr_restarts.arn
}

resource "aws_sns_topic_subscription" "solr_memory_email_target" {
  count     = var.emailNotification == "" ? 0 : 1
  topic_arn = aws_sns_topic.solr_memory_updates.arn
  protocol  = "email"
  endpoint  = var.emailNotification
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_solr_${local.lb_name}_restarts"

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

resource "aws_iam_role_policy_attachment" "lambda_operations" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_operations.arn
}

resource "aws_iam_policy" "lambda_operations" {
  name        = "solr-${local.lb_name}-lambda_operations"
  path        = "/"
  description = "IAM policy for logging/ecs-restarts from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:*"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_cloudwatch_log_group" "lambda-restarts" {
  name              = "/aws/lambda/solr-${local.lb_name}-restarts"
  retention_in_days = 14
}

resource "local_file" "app" {
  content  = local.restarts_app_template
  filename = "${path.module}/package/app.py"
}

data "archive_file" "package_app" {

  source_dir  = "${path.module}/package"
  output_path = "${path.module}/restart_app.zip"
  type        = "zip"

  depends_on = [
    local_file.app,
  ]
}


resource "aws_lambda_function" "solr_restarts" {
  function_name    = "solr-${local.lb_name}-restarts"
  role             = aws_iam_role.iam_for_lambda.arn
  runtime          = "python3.13"
  filename         = data.archive_file.package_app.output_path
  source_code_hash = data.archive_file.package_app.output_sha256
  handler          = "app.handler"

  package_type = "Zip"
}
