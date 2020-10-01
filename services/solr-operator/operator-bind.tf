# These inputs will come from the output of the provision operation
variable "namespace" { type = string }
variable "server" { type = string }
variable "token" { type = string }
variable "cluster_ca_certificate" { type = string }
variable "read_only" { type = bool }

output "namespace" { value = var.namespace }
output "server" { value = var.server }
output "token" { value = base64encode(data.kubernetes_secret.secret.data.token) }
output "cluster_ca_certificate" { value = var.cluster_ca_certificate }

provider "kubernetes" {
  host                   = var.server
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  token                  = base64decode(var.token)
  load_config_file       = false
}

data "kubernetes_namespace" "solr" {
  metadata {
    name        = var.namespace
    annotations = {}
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Provision a k8s service account and secret
# ---------------------------------------------------------------------------------------------------------------------
locals {
  role        = var.read_only ? "solrcloud-access-read-only" : "solrcloud-access-all"
  name_prefix = var.read_only ? "monitor-" : "admin-"
  label       = var.read_only ? "monitor" : "admin"
}

resource "kubernetes_service_account" "service_account" {
  metadata {
    generate_name = local.name_prefix
    namespace     = var.namespace
    labels = {
      role = local.label
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Bind the service account to the appropriate role
# ---------------------------------------------------------------------------------------------------------------------

resource "kubernetes_role_binding" "service_account_role_binding" {
  metadata {
    name      = "${kubernetes_service_account.service_account.metadata[0].name}-${local.role}-role-binding"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = local.role
  }

  subject {
    api_group = ""
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.service_account.metadata[0].name
    namespace = var.namespace
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# Read in the generated (default) secret for the service account
# ---------------------------------------------------------------------------------------------------------------------
data "kubernetes_secret" "secret" { 
  metadata {
    name = kubernetes_service_account.service_account.default_secret_name
    namespace = var.namespace
  }
}