# ===
# Vars
variable "cluster_id" {
  description = "The cluster ID to target from the passed kubeconfig"
  default = "docker-desktop"
}

variable "operator" {
  type = string
  description = "The operator to target. Use an output from solr-operator!"
}

variable "cloud_name" {
  type = string
  description = "The name of the cloud to create (used only for demo purposes)"
  default = ""
}

# ===
# Providers
provider "kubernetes" {
  config_context_cluster   = var.cluster_id
}

provider "helm" {
  kubernetes {
    config_context_cluster   = var.cluster_id
  }
}

# ===
# k8s namespaces
data "kubernetes_namespace" "namespace" {
  metadata {
    name = var.operator
  }
}

# --- create-service starts here
resource "helm_release" "solrcloud" {
  name = local.cloud_name
  chart = "./solr-crd"
  namespace = data.kubernetes_namespace.namespace.id
  cleanup_on_fail = "true"
  atomic = "true"

  set {
    name  = "ingressBaseDomain"
    value = var.cloud_name == "example" ? "ing.local.domain" : data.kubernetes_namespace.namespace.metadata[0].annotations.ingress_base_domain
  }

  # provisioner "local-exec" {
  #   command = "helm --kube-context ${var.cluster_id} test -n ${self.namespace} ${self.name}"
  # }
}

# --- bind-service starts here


# To be used in the generated URL at bind time...
data "kubernetes_ingress" "solrcloud-ingress" {
  metadata {
    name = "${local.cloud_name}-solrcloud-common"
    namespace = var.operator
  }
  depends_on = [ helm_release.solrcloud ]
}

# We're generating these randomly now because they're ignored anyway, 
# but in future we're going to have to create a secret with these creds and
# get solr-operator to reference it when creating our ingress rule. See
# https://kubernetes.github.io/ingress-nginx/examples/auth/basic/
resource "random_id" "solrcloud_name" {
  byte_length = 8
}
locals {
  cloud_name = var.cloud_name != "" ? var.cloud_name : lower(random_id.solrcloud_name.b64_url)
}
resource "random_uuid" "client_username" {}
resource "random_password" "client_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

output "uri" {
  value = format("%s://%s:%s@%s",
    "http", # We need to derive this programmatically from the kubernetes_ingress in future. 
    random_uuid.client_username.result,
    random_password.client_password.result,
    data.kubernetes_ingress.solrcloud-ingress.spec[0].rule[0].host)
}
