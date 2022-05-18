
resource "aws_lb" "solr" {
  name               = "solr-${var.instance_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.solr-lb-sg.id]
  subnets            = module.vpc.private_subnets

  enable_deletion_protection = true

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
  certificate_arn = aws_acm_certificate.cert.arn

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.solr-target.id
  }
}

resource "aws_lb_target_group" "solr-target" {
  name        = "solr-${var.instance_name}-tg"
  port        = 8983
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = module.vpc.vpc_id

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 5
    interval = 30
    path = "/"
    port = 8983
    protocol = "HTTP"
    timeout = 10
  }
}

resource "aws_security_group" "solr-lb-sg" {
  name        = "solr-${var.instance_name}-sg"
  description = "Allow TLS inbound traffic to Solr"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description      = "TLS from users/application"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "HTTP to upgrade"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  ingress {
    description      = "solr cluster"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = module.vpc.private_subnets_cidr_blocks
  }
  egress {
    description      = "solr cluster"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = module.vpc.private_subnets_cidr_blocks
  }
}
