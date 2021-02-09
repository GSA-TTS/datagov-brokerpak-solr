locals {
  cloud_name = var.cloud_name != "" ? var.cloud_name : lower(random_id.solrcloud_name.b64_url)
}

# We're generating these randomly now because they're ignored anyway, 
# but in future we're going to have to create a secret with these creds and
# get solr-operator to reference it when creating our ingress rule. See
# https://kubernetes.github.io/ingress-nginx/examples/auth/basic/
resource "random_id" "solrcloud_name" {
  byte_length = 8
}

# TODO: Create an nginx-ingress HTTP AUTH secret resources that correspond to these
# credentials: https://kubernetes.github.io/ingress-nginx/examples/auth/basic/
resource "random_uuid" "client_username" {}
resource "random_password" "client_password" {
  length           = 16
  special          = false
#  override_special = "_%@"
}

resource "kubernetes_secret" "solr_auth1" {
  metadata {
    name = "basic-auth1"
    namespace = var.namespace
  }

  data = {
    auth = "${random_uuid.client_username.result}:${bcrypt(random_password.client_password.result)}"
  }

  type = "Opaque"
}


# Instantiate a SolrCloud instance using the CRD
resource "helm_release" "solrcloud" {
  name = local.cloud_name
  chart = "https://github.com/GSA/datagov-brokerpak/releases/download/helm-chart-release/solr-crd.tar.gz"
  namespace = data.kubernetes_namespace.namespace.id
  cleanup_on_fail = true
  atomic = true
  wait = true
  timeout = 600

  set {
    name  = "ingressBaseDomain"
    # Since we're no longer in charge of creating the namespace, we need to
    # ensure that the ingressBaseDomain is available in some other way! Again:
    # Can we query it from the nginx-ingress pod in k8s itself?
    # value = var.cloud_name == "example" ? "ing.local.domain" : data.kubernetes_namespace.namespace.metadata[0].annotations.ingress_base_domain

    # For now, we'll just use what was passed in
    value = var.ingress_base_domain
  }

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

  # TODO: We should have a local-exec provisioner with a timeout here to verify that Solr is
  # actually available before returning.

}

