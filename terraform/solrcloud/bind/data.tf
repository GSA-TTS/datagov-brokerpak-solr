# Derive the ingress hostname that's used for connecting to the exposed SolrCloud
data "kubernetes_ingress" "solrcloud-ingress" {
  metadata {
    name      = "${local.cloud_name}-solrcloud-common"
    namespace = var.namespace
  }
}

data "kubernetes_secret" "solr_creds" {
  metadata {
    name = "${local.cloud_name}-solrcloud-security-bootstrap"
  }
}

data "kubernetes_service" "solr_api" {
  metadata {
    name = "${local.cloud_name}-solrcloud-common"
  }
}
