
resource "aws_service_discovery_private_dns_namespace" "solr" {
  name        = "solr-${local.lb_name}"
  description = "Internal solr-to-solr communication link"
  vpc         = module.vpc.vpc_id
}

resource "aws_service_discovery_service" "solr" {
  name = local.lb_name

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.solr.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "solr-follower" {
  count = var.solrFollowerCount
  name = "${local.lb_name}-follower-${count.index}"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.solr.id
    dns_records {
      ttl  = 10
      type = "A"
    }
    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
