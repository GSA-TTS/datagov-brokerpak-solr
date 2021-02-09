data "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

# Derive the ingress hostname that's used for connecting to the exposed SolrCloud
data "kubernetes_ingress" "solrcloud-ingress" {
  metadata {
    name = "${var.cloud_name}-solrcloud-common"
    namespace = var.namespace
  }
}