
variable "ingress_base_domain" { type = string }
variable "namespace" { type = string }
variable "server" { type = string }
variable "cluster_ca_certificate" { type = string }
variable "token" { type = string }

# Not all of these will be output; most will just be passed on for use in binding
output "namespace" { value = var.namespace }
output "server" { value = var.server }
output "token" { value = var.token }
output "cluster_ca_certificate" { value = var.cluster_ca_certificate }

# ==============
# Implementation
# ==============
provider "kubernetes" {
#  config_context_cluster = var.cluster_id
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

# ---------------------------------------------------------------------------------------------------------------------
# Install the zookeeper and solr operator Helm charts in the namespace
# ---------------------------------------------------------------------------------------------------------------------
data "kubernetes_namespace" "operator" {
  metadata {
    name = var.namespace
    annotations = {
    }
  }
}

resource "helm_release" "zookeeper" {
  name            = "zookeeper"
  chart           = "zookeeper-operator"
  repository      = "https://charts.pravega.io/"
  namespace       = data.kubernetes_namespace.operator.id
  cleanup_on_fail = "true"
  atomic          = "true"
}

resource "helm_release" "solr" {
  name            = "solr"
  chart           = "solr-operator"
  repository      = "https://bloomberg.github.io/solr-operator/charts"
  namespace       = data.kubernetes_namespace.operator.id
  cleanup_on_fail = "true"
  atomic          = "true"

  set {
    name  = "ingressBaseDomain"
    value = var.ingress_base_domain
  }
}
