variable "server" { type = string }
variable "cluster_ca_certificate" { type = string }
variable "token" { type = string }
variable "namespace" { type = string }
variable "ingress_base_domain" { type = string }

variable "replicas" { type = number }
variable "solrImageTag" { type = string }
variable "solrJavaMem" { type = string }

variable "cloud_name" {
  type = string
  description = "The name of the cloud to create (used only for demo purposes)"
  default = ""
}

# Not all of these will be output; most will just be passed on for use in binding
output "namespace" { value = var.namespace }
output "server" { value = var.server }
output "token" { value = var.token }
output "cluster_ca_certificate" { value = var.cluster_ca_certificate }
output "cloud_name" { value = local.cloud_name }

# ==============
# Implementation
# ==============
provider "kubernetes" {
  host                   = var.server
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  token                  = base64decode(var.token)
  load_config_file       = false
}

provider "helm" {
  kubernetes {
    host                   = var.server
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
    token                  = base64decode(var.token)
    load_config_file       = false
  }
}

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

# Get ahold of the k8s namespace where the solr-operator CRDs are available
data "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
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

  # TODO: We should have a loop with a timeout here to verify that Solr is
  # actually available before returning.

}

