# =========
# Interface
# =========
variable "cluster_id" {
  description = "The cluster ID to target from the passed kubeconfig"
  default     = "docker-desktop"
}

# Does the customer have to know? Can this be derived from the existing ingress
# controller in the provided k8s?
variable "ingress_base_domain" {
  description = "The base domain to expose Solr on, eg *.(ingress-base-domain)"
  default     = "ing.local.domain"
}

variable "operator_name" {
  type = string
  description = "The namespace to use (null generates, specify only for demo purposes)"
  default = ""
}

output "operator" {
  value = local.operator_name
}

# ==============
# Implementation
# ==============
provider "kubernetes" {
  config_context_cluster = var.cluster_id
}

provider "helm" {
  kubernetes {
    config_context_cluster = var.cluster_id
  }
}

# This is a workaround because kubernetes_namespace.metadata.generate_name
# generates a namespace we can't use as data elsewhere. See reported bug:
# https://github.com/hashicorp/terraform-provider-kubernetes/issues/1009
resource "random_id" "namespace" {
  prefix = "solr-operator-"
  byte_length = 5
}
locals {
  operator_name = var.operator_name != "" ? var.operator_name : lower(random_id.namespace.b64_url) 
}

# There should be a namespace with the zookeeper and solr operator Helm charts installed
resource "kubernetes_namespace" "operator" {
  count = var.operator_name != "" ? 0 : 1
  metadata {
    name = local.operator_name
    annotations = {
      ingress_base_domain = var.ingress_base_domain
    }
  }
}

data "kubernetes_namespace" "operator" {
  count = var.operator_name != "" ? 1 : 0
  metadata {
    name = local.operator_name
    annotations = {
      ingress_base_domain = var.ingress_base_domain
    }
  }
}

resource "helm_release" "zookeeper" {
  name            = "zookeeper"
  chart           = "zookeeper-operator"
  repository      = "https://charts.pravega.io/"
#  namespace       = kubernetes_namespace.operator.id
  namespace       = local.operator_name
  cleanup_on_fail = "true"
  atomic          = "true"

  provisioner "local-exec" {
    command = "helm --kube-context ${var.cluster_id} test -n ${self.namespace} ${self.name}"
  }
}

resource "helm_release" "solr" {
  name            = "solr"
  chart           = "solr-operator"
  repository      = "https://bloomberg.github.io/solr-operator/charts"
#  namespace       = kubernetes_namespace.operator.id
  namespace       = local.operator_name
  cleanup_on_fail = "true"
  atomic          = "true"

  set {
    name  = "ingressBaseDomain"
    value = var.ingress_base_domain
  }

  provisioner "local-exec" {
    command = "helm --kube-context ${var.cluster_id} test -n ${self.namespace} ${self.name}"
  }
}
