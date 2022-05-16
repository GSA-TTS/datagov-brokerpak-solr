

# resource "aws_lb" "solr" {
#   name               = "solr-lb"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.lb_sg.id]
#   subnets            = [for subnet in aws_subnet.public : subnet.id]
# 
#   enable_deletion_protection = true
# 
#   access_logs {
#     bucket  = aws_s3_bucket.lb_logs.bucket
#     prefix  = "test-lb"
#     enabled = true
#   }
# 
#   tags = {
#     Environment = "production"
#   }
# }
