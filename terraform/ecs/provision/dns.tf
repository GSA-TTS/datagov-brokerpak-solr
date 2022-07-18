# -----------------------------------------------------------------
# SETUP DNS+DNSSEC for the cluster
# -----------------------------------------------------------------

# get externally configured DNS Zone 
data "aws_route53_zone" "zone" {
  name = var.zone
}

# Create hosted zone for cluster-specific subdomain name
resource "aws_route53_zone" "cluster" {
  name = local.domain
  # There may be extraneous DNS records from external-dns; that's expected.
  force_destroy = true
  tags = merge(var.labels, {
    Environment = var.instance_name
    domain      = local.domain
  })
}

# Delegate DNS resolution for things in the cluster zone by creating a NS record in the parent zone
resource "aws_route53_record" "cluster-ns" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = local.domain
  type    = "NS"
  ttl     = "30"
  records = aws_route53_zone.cluster.name_servers
}

# Create a KMS key for DNSSEC signing
resource "aws_kms_key" "cluster" {

  # This is all boilerplate. See Route53 key requirements here: 
  # https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring-dnssec-cmk-requirements.html
  provider                 = aws.dnssec-key-provider # Only us-east-1 is supported
  customer_master_key_spec = "ECC_NIST_P256"
  deletion_window_in_days  = 7
  key_usage                = "SIGN_VERIFY"
  policy = jsonencode({
    Statement = [
      {
        Action = [
          "kms:DescribeKey",
          "kms:GetPublicKey",
          "kms:Sign",
        ],
        Effect = "Allow"
        Principal = {
          Service = "dnssec-route53.amazonaws.com"
        }
        Sid      = "Allow Route 53 DNSSEC Service",
        Resource = "*"
      },
      {
        Action = "kms:CreateGrant",
        Effect = "Allow"
        Principal = {
          Service = "dnssec-route53.amazonaws.com"
        }
        Sid      = "Allow Route 53 DNSSEC Service to CreateGrant",
        Resource = "*"
        Condition = {
          Bool = {
            "kms:GrantIsForAWSResource" = "true"
          }
        }
      },
      {
        Action = "kms:*"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Resource = "*"
        Sid      = "IAM User Permissions"
      },
    ]
    Version = "2012-10-17"
  })
}

# Make it easier for admins to identify the key in the KMS console
resource "aws_kms_alias" "cluster" {
  provider      = aws.dnssec-key-provider
  name          = "alias/DNSSEC-${split(".", local.domain)[0]}"
  target_key_id = aws_kms_key.cluster.key_id
}

# Configure the cluster zone with the signing key
resource "aws_route53_key_signing_key" "cluster" {
  hosted_zone_id             = aws_route53_zone.cluster.id
  key_management_service_arn = aws_kms_key.cluster.arn
  name                       = local.domain
}

# Turn DNSSEC signing on for the cluster zone
resource "aws_route53_hosted_zone_dnssec" "cluster" {
  depends_on = [
    aws_route53_key_signing_key.cluster
  ]
  hosted_zone_id = aws_route53_key_signing_key.cluster.hosted_zone_id
}

# Establish chain of trust from the parent zone by putting a Delegated Signer (DS) record there
resource "aws_route53_record" "cluster-ds" {
  depends_on = [
    aws_route53_hosted_zone_dnssec.cluster
  ]
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = local.domain
  type    = "DS"
  ttl     = "30"
  records = [aws_route53_key_signing_key.cluster.ds_record]
}

# CNAME to Solr Leader Load Balancer
resource "aws_route53_record" "solr" {
  zone_id = aws_route53_zone.cluster.zone_id
  name    = local.leader_domain
  type    = "CNAME"
  ttl     = "120"
  records = [aws_lb.solr.dns_name]
}

# CNAME to Solr Follower Load Balancer
resource "aws_route53_record" "solr-follower" {
  count   = var.solrFollowerCount == 0 ? 0 : 1
  zone_id = aws_route53_zone.cluster.zone_id
  name    = replace(local.follower_domain, "-placeholder", "")
  type    = "CNAME"
  ttl     = "120"
  records = [aws_lb.solr-follower[count.index].dns_name]
}
