# ===
# Vars
variable "cluster_id" {
  description = "The cluster ID to target from the passed kubeconfig"
  default = "docker-desktop"
}

variable "ingress_base_domain" {
  description = "The base domain to expose Solr on, eg *.(ingress-base-domain)"
  default = "ing.local.domain"
}
# ===
# Providers
provider "kubernetes" {
  config_context_cluster   = "docker-desktop"
}

provider "helm" {
  kubernetes {
    config_context_cluster   = var.cluster_id
  }
}

# ===
# k8s namespaces
resource "kubernetes_namespace" "nginx-ingress" {
  metadata {
    name = "nginx-ingress"
  }
}

resource "kubernetes_namespace" "solr" {
  metadata {
    name = "solr"
  }
}

# ===
# Helm charts

# Ingress should be assumed of whatever k8s provider is passed in, but for now...
resource "helm_release" "ingress" {
  name = "ingress"
  chart = "nginx-ingress"
  repository = "https://helm.nginx.com/stable"
  namespace = "nginx-ingress"
  cleanup_on_fail = "true"
  atomic = "true"

  provisioner "local-exec" {
    command = "helm --kube-context ${var.cluster_id} test -n ${self.namespace} ${self.name}"
  }
}

resource "helm_release" "zookeeper" {
  name = "zookeeper"
  chart = "zookeeper-operator"
  repository = "https://charts.pravega.io/"
  namespace = "solr"
  cleanup_on_fail = "true"
  atomic = "true"

  provisioner "local-exec" {
    command = "helm --kube-context ${var.cluster_id} test -n ${self.namespace} ${self.name}"
  }
}

resource "helm_release" "solr" {
  name = "solr"
  chart = "solr-operator"
  repository = "https://bloomberg.github.io/solr-operator/charts"
  namespace = "solr"
  cleanup_on_fail = "true"
  atomic = "true"

  set {
    name  = "ingressBaseDomain"
    value = var.ingress_base_domain
  }

  provisioner "local-exec" {
    command = "helm --kube-context ${var.cluster_id} test -n ${self.namespace} ${self.name}"
  }
}

resource "helm_release" "solrcloud" {
  name = "example"
  chart = "solr-crd"
  cleanup_on_fail = "true"
  atomic = "true"

  # set {
  #   name  = "ingressBaseDomain"
  #   value = var.ingress_base_domain
  # }

  # provisioner "local-exec" {
  #   command = "helm --kube-context ${var.cluster_id} test -n ${self.namespace} ${self.name}"
  # }
}

data "kubernetes_ingress" "example-solrcloud" {
  metadata {
    name = "example-solrcloud-common"
  }
}

output "uri" {
  value = format("%s://%s",
    "http",
    data.kubernetes_ingress.example-solrcloud.spec[0].rule[0].host)
}