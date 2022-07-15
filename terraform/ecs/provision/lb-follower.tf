
resource "aws_lb" "solr-follower" {
  count   = var.solrFollowerCount == 0 ? 0 : 1
  name               = "${local.lb_name}-follower-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.solr-lb-sg.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  # access_logs {
  #   bucket  = aws_s3_bucket.lb_logs.bucket
  #   prefix  = "test-lb"
  #   enabled = true
  # }

  tags = {
    name = "solr-${var.instance_name}"
  }
}

resource "aws_lb_listener" "http_upgrade-follower" {
  count   = var.solrFollowerCount == 0 ? 0 : 1
  load_balancer_arn = aws_lb.solr-follower[count.index].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https_response-follower" {
  count   = var.solrFollowerCount == 0 ? 0 : 1
  load_balancer_arn = aws_lb.solr-follower[count.index].arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.solr-follower-target[count.index].id
  }
}

resource "aws_lb_target_group" "solr-follower-target" {
  count   = var.solrFollowerCount == 0 ? 0 : 1
  name        = "${local.lb_name}-follower-tg"
  port        = 8983
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    path                = "/"
    port                = 8983
    protocol            = "HTTP"
    timeout             = 10
    matcher             = "200-399"
  }
}
