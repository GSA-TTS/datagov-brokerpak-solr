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

resource "kubernetes_manifest" "zookeeperinstance" {
  provider = kubernetes-alpha
  manifest = {
    "apiVersion" = "zookeeper.pravega.io/v1beta1"
    "kind"       = "ZookeeperCluster"
    "metadata" = {
      "name"      = "${local.cloud_name}-zookeeper"
      "namespace" = data.kubernetes_namespace.namespace.id
    }
    "spec" = {
      "replicas"    = 3
      "storageType" = "ephemeral"
    }
  }
}

resource "kubernetes_manifest" "solrcloudinstance" {
  provider = kubernetes-alpha
  manifest = {
    "apiVersion" = "solr.bloomberg.com/v1beta1"
    "kind"       = "SolrCloud"
    "metadata" = {
      "name"      = local.cloud_name
      "namespace" = data.kubernetes_namespace.namespace.id
    }
    "spec" = {
      "replicas" = var.replicas
      "solrImage" = {
        "repository" = "docker.io/solr"
        "tag"        = var.solrImageTag
      }
      "dataStorage" = {
        "ephemeral" = {
          # We are not specifying an emptyDir volume source here, but we could
          # See https://github.com/apache/solr-operator/blob/main/docs/solr-cloud/solr-cloud-crd.md#data-storage
          "emptyDir" = {}
        }
      }
      "solrJavaMem" = var.solrJavaMem
      "solrAddressability" = {
        "external" = {
          "domainName" = var.domain_name
          "method"     = "Ingress"
        }
      }
      "customSolrKubeOptions" = {
        "ingressOptions" = {
          "annotations" = {
            "nginx.ingress.kubernetes.io/auth-realm"  = "Authentication Required - admin"
            "nginx.ingress.kubernetes.io/auth-secret" = kubernetes_secret.client_creds.metadata[0].name
            "nginx.ingress.kubernetes.io/auth-type"   = "basic"
          }
        }
      }
      "zookeeperRef" = {
        "connectionInfo" = {
          "externalConnectionString" = "test-ephemeral-zookeeper-client.default:2181"
        }
      }
    }
  }
}
