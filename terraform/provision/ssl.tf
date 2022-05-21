
locals {
  domain = "solr-${local.lb_name}.${var.zone}"
}

# Create ACM certificate for the sub-domain
resource "aws_acm_certificate" "cert" {
  domain_name       = local.domain
  validation_method = "DNS"
  tags = merge(var.labels, {
    environment = var.instance_name
  })
}

# Validate the certificate using DNS method
resource "aws_route53_record" "cert_validation" {
  name    = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_type
  zone_id = aws_route53_zone.cluster.id
  records = [tolist(aws_acm_certificate.cert.domain_validation_options)[0].resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}
