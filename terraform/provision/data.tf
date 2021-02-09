# Get ahold of the k8s namespace where the solr-operator CRDs are available
data "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

