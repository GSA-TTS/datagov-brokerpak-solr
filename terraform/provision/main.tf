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

data "template_file" "kubeconfig" {
  template = <<-EOF
    apiVersion: v1
    kind: Config
    current-context: terraform
    clusters:
    - name: cluster
      cluster:
        certificate-authority-data: ${var.cluster_ca_certificate}
        server: ${var.server}
    contexts:
    - name: terraform
      context:
        namespace: ${var.namespace}
        cluster: cluster
        user: terraform
    users:
    - name: terraform
      user:
        token: ${base64decode(var.token)}
  EOF
}

# Instantiate a SolrCloud instance using the CRD
resource "helm_release" "solrcloud" {
  name            = local.cloud_name
  chart           = "https://github.com/GSA/datagov-brokerpak/releases/latest/download/solr-crd.tar.gz"
  namespace       = data.kubernetes_namespace.namespace.id
  cleanup_on_fail = true
  atomic          = true
  wait            = true
  timeout         = 900

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

  set {
    # The name of the secret to be used for authentication
    name  = "secretName"
    value = kubernetes_secret.client_creds.metadata[0].name
  }

  set {
    # The name of the domain to be used for ingress
    name  = "domainName"
    value = var.domain_name
  }

  # The helm_release "wait" flag is supposed to wait for all pods to be
  # "ready" before completing but there appears to be a bug in that behavior.
  # https://github.com/hashicorp/terraform-provider-helm/issues/672
  # 
  # This command explicitly waits to get around that.
  provisioner "local-exec" {
    environment = {
      KUBECONFIG = base64encode(data.template_file.kubeconfig.rendered)
    }
    command = <<-EOF
      echo should fail
      exit 1
      sleep 30
      kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) wait --for=condition=ready --timeout=3600s -n ${data.kubernetes_namespace.namespace.id} pod -l solr-cloud=${local.cloud_name}
    EOF
  }

}

