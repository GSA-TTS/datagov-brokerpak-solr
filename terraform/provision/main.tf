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
  chart           = "solr"
  repository      = "https://solr.apache.org/charts"
  namespace       = var.namespace
  cleanup_on_fail = true
  atomic          = true
  wait            = true
  timeout         = 900

  dynamic "set" {
    for_each = {
      "addressability.external.domainName"         = var.domain_name # The name of the domain to be used for ingress
      "addressability.external.method"             = "Ingress"
      "addressability.external.useExternalAddress" = true
      "dataStorage.type"                           = "ephemeral"
      "image.repository"                           = var.solrImageRepo # Which Docker repo to use for pulling the Solr image (defaults to docker.io/solr)
      "image.tag"                                  = var.solrImageTag  # Which version of Solr to use (specify a tag from the official Solr images at https://hub.docker.com/_/solr)
      "podOptions.resources.requests.memory"       = var.solrMem       # How much memory to request from the scheduler
      "podOptions.resources.requests.cpu"          = var.solrCpu       # How much vCPU to request from the scheduler
      "replicas"                                   = var.replicas      # How many replicas you want
      "solrOptions.javaMemory"                     = var.solrJavaMem   # How much memory to give each replica
      "solrOptions.security.authenticationType"    = "Basic"
      "ingressOptions.annotations.nginx\\.ingress\\.kubernetes\\.io/proxy-body-size" = 999m
    }
    content {
      name  = set.key
      value = set.value
    }
  }

  # The helm_release "wait" flag is supposed to wait for all pods to be
  # "ready" before completing but there appears to be a bug in that behavior.
  # https://github.com/hashicorp/terraform-provider-helm/issues/672
  # 
  # This command explicitly waits to get around that.
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = base64encode(data.template_file.kubeconfig.rendered)
    }
    command = <<-EOF
      sleep 30
      kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) wait --for=condition=ready --timeout=3600s -n ${var.namespace} pod -l solr-cloud=${local.cloud_name}
    EOF
  }

}

