variable "server" { type = string }
variable "cluster_ca_certificate" { type = string }
variable "token" { type = string }
variable "namespace" { type = string }
variable "cloud_name" { type = string }

output "uri" {
  value = format("%s://%s:%s@%s",
    "http", # We need to derive this programmatically from the kubernetes_ingress in future. 
    random_uuid.client_username.result,
    random_password.client_password.result,
    data.kubernetes_ingress.solrcloud-ingress.spec[0].rule[0].host)
}

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

# TODO: Create an nginx-ingress HTTP AUTH secret resources that correspond to these
# credentials: https://kubernetes.github.io/ingress-nginx/examples/auth/basic/
resource "random_uuid" "client_username" {}
resource "random_password" "client_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

# Get ahold of the k8s namespace where the solr-operator CRDs are available
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

