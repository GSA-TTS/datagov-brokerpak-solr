variable "server" { type = string }
variable "cluster_ca_certificate" { type = string }
variable "token" { type = string }
variable "namespace" { type = string }
variable "cloud_name" { type = string }
variable "username" { type = string }
variable "password" { type = string }

output "uri" {
  value = format("%s://%s:%s@%s",
    "http", # We need to derive this programmatically from the kubernetes_ingress in future. 
    var.username,
    var.password,
    data.kubernetes_ingress.solrcloud-ingress.spec[0].rule[0].host)
}
output "namespace" { value = "" }
output "server" { value = "" }
output "token" { value = "" }
output "cluster_ca_certificate" { value = "" }
output "cloud_name" { value = "" }
output "username" { value = "" }
output "password" { value = "" }

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

