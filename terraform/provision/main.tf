# We create the secret to be used for authentication here, then add a new set of
# credentials to data.auth upon each binding.
resource "kubernetes_secret" "client_creds" {
  metadata {
    name      = "${local.cloud_name}-creds"
    namespace = var.namespace
  }

  data = {
    auth = base64encode("")
  }

  type = "Opaque"
}


# Instantiate a SolrCloud instance using the CRD
resource "helm_release" "solrcloud" {
  name            = local.cloud_name
  chart           = "https://github.com/GSA/datagov-brokerpak/releases/download/helm-chart-release/solr-crd.tar.gz"
  namespace       = data.kubernetes_namespace.namespace.id
  cleanup_on_fail = true
  atomic = true
  wait = true
  timeout = 600

  set {
    # How many replicas you want
    name  = "replicas"
    value = var.replicas
  }

  set {
    # Which version of Solr to use (specify a tag from the official Solr images at https://hub.docker.com/_/solr)
    name  = "solrImageTag"
    value = var.solrImageTag
  }

  set {
    # How much memory to give each replica
    name  = "solrJavaMem"
    value = var.solrJavaMem
  }

  set {
    # The name of the secret to be used for authentication
    name  = "secretName"
    value = kubernetes_secret.client_creds.metadata[0].name
  }

  set {
    # The name of the domain to be used for ingress
    name  = "domainName"
    value = var.domain_name
  }

  # TODO: We should have a local-exec provisioner with a timeout here to verify that Solr is
  # actually available before returning.

}

