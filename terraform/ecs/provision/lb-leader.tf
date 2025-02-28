
locals {
  lb_name = substr(var.instance_name, 0, 13)
}

resource "aws_lb" "solr" {
  name               = "${local.lb_name}-lb"
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

resource "aws_lb_listener" "http_upgrade" {
  load_balancer_arn = aws_lb.solr.arn
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

resource "aws_lb_listener" "https_response" {
  load_balancer_arn = aws_lb.solr.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.solr-target.id
  }
}

resource "aws_lb_target_group" "solr-target" {
  name        = "${local.lb_name}-tg"
  port        = 8983
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id
  deregistration_delay  = 90

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

resource "aws_security_group" "solr-lb-sg" {
  name        = "solr-${var.instance_name}-sg"
  description = "Allow TLS inbound traffic to Solr"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "incoming_tls" {
  security_group_id = aws_security_group.solr-lb-sg.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol    = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "incoming_http" {
  security_group_id = aws_security_group.solr-lb-sg.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol    = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "incoming_follower_http" {
  security_group_id = aws_security_group.solr-lb-sg.id
  cidr_ipv4 = "0.0.0.0/0"
  from_port   = 9000
  to_port     = 9000 + var.solrFollowerCount
  ip_protocol    = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "cluster_ingress" {
  security_group_id = aws_security_group.solr-lb-sg.id
  from_port       = 0
  to_port         = 0
  ip_protocol        = "-1"
  referenced_security_group_id = module.vpc.default_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "cluster_egress" {
  security_group_id = aws_security_group.solr-lb-sg.id
  from_port       = 0
  to_port         = 0
  ip_protocol        = "-1"
  referenced_security_group_id = module.vpc.default_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "ghcr_egress" {
  security_group_id = aws_security_group.solr-lb-sg.id
  from_port   = 0
  to_port     = 65535
  ip_protocol    = "tcp"
  cidr_ipv4 = "0.0.0.0/0"
}
