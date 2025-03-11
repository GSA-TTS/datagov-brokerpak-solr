
locals {
  domain          = "solr-${local.lb_name}.${var.zone}"
  leader_domain   = "leader.${local.domain}"
  follower_domain = "follower.${local.domain}"
}

# Create ACM certificate for the sub-domain
resource "aws_acm_certificate" "cert" {
  domain_name               = local.domain
  subject_alternative_names = ["*.${local.domain}"]

  validation_method = "DNS"
  tags = merge(var.labels, {
    environment = var.instance_name
  })
}

# Validate the certificate using DNS method (Parent Domain and subdomains)
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
    if !startswith(dvo.domain_name, "*")
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.cluster.zone_id
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
