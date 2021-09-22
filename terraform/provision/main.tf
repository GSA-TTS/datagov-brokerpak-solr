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


resource "kubernetes_secret" "security_json" {
  metadata {
    # TODO: This should replace the bootstrapped security.json
    name      = "${local.cloud_name}-security-bootstrap"
    # name      = "${local.cloud_name}-solrcloud-security-bootstrap"
    namespace = var.namespace
    labels    = {
      "app.kubernetes.io/instance"    = "${local.cloud_name}"
      "app.kubernetes.io/managed-by"  = "data.gov"
      "app.kubernetes.io/name"        = "solr"
      "app.kubernetes.io/version"     = "8.9.0"
      "helm.sh/chart"                 = "solr-0.4.0"
      "solr-cloud"                    = "${local.cloud_name}"
    }
  }

  data = {
    # TODO: These should be created via bind, but provision should at least restrict access to everyone
    # "admina" = base64encode("password")
    # "k8sop" = base64encode("password")
    # 
    # The "security.json" attribute doesn't register with solr and doesn't restrict users, needs to be fixed
    "security.json" = base64encode(tostring(jsonencode(
    {
  "authentication": {
    "blockUnknown": true,
    "class": "solr.BasicAuthPlugin",
    "credentials": {
      "admina": base64encode("password"),
      "k8sop": base64encode("password")
    },
    "realm": "Solr Basic Auth",
    "forwardCredentials": false
  },
  "authorization": {
    "class": "solr.RuleBasedAuthorizationPlugin",
    "user-role": {
      "admina": [ "admin", "k8s" ],
      "k8s-op": [ "admin", "k8s" ]
    },
    "permissions": [
      {
        "name": "k8s-probe-0",
        "role": null,
        "collection": null,
        "path": "/admin/info/system"
      },
      {
        "name": "k8s-status",
        "role": "k8s",
        "collection": null,
        "path": "/admin/collections"
      },
      {
        "name": "k8s-metrics",
        "role": "k8s",
        "collection": null,
        "path": "/admin/metrics"
      },
      {
         "name": "k8s-zk",
         "role":"k8s",
         "collection": null,
         "path":"/admin/zookeeper/status"
      },
      {
        "name": "k8s-ping",
        "role": "k8s",
        "collection": "*",
        "path": "/admin/ping"
      },
      {
        "name": "read",
        "role": [ "admin", "users" ]
      },
      {
        "name": "update",
        "role": [ "admin" ]
      },
      {
        "name": "security-read",
        "role": [ "admin" ]
      },
      {
        "name": "security-edit",
        "role": [ "admin" ]
      },
      {
        "name": "all",
        "role": [ "admin" ]
      }
    ]
  }})))
  }

  type = "Opaque"
}

resource "kubernetes_secret" "operator_auth" {
  metadata {
    # TODO: This should replace the bootstrapped basic-auth to communicate with solr operator
    name      = "${local.cloud_name}-basic-auth"
    # name      = "${local.cloud_name}-solrcloud-basic-auth"
    namespace = var.namespace
  }

  data = {
    username = base64encode("k8sop")
    password = base64encode("password")
  }

  type = "kubernetes.io/basic-auth"
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
  chart           = "solr"
  repository      = "https://solr.apache.org/charts"
  namespace       = data.kubernetes_namespace.namespace.id
  cleanup_on_fail = true
  atomic          = true
  wait            = true
  timeout         = 900

  dynamic "set" {
    for_each = {
      "addressability.external.domainName"                                      = var.domain_name # The name of the domain to be used for ingress
      "addressability.external.method"                                          = "Ingress"
      "addressability.external.useExternalAddress"                              = true
      "dataStorage.type"                                                        = "ephemeral"
      "image.repository"                                                        = var.solrImageRepo                               # Which Docker repo to use for pulling the Solr image (defaults to docker.io/solr)
      "image.tag"                                                               = var.solrImageTag                                # Which version of Solr to use (specify a tag from the official Solr images at https://hub.docker.com/_/solr)
      # "ingressOptions.annotations.nginx\\.ingress\\.kubernetes\\.io/auth-type"  = "basic"
      # "ingressOptions.annotations.nginx\\.ingress\\.kubernetes\\.io/auth-realm" = "Authentication Required - admin"
      # "ingressOptions.annotations.nginx\\.ingress\\.kubernetes\\.io/auth-secret"= kubernetes_secret.client_creds.metadata[0].name # The name of the secret to be used for authentication
      "podOptions.resources.requests.memory"                                    = var.solrMem # How much memory to request from the scheduler
      "podOptions.resources.requests.cpu"                                       = var.solrCpu # How much vCPU to request from the scheduler
      "replicas"                                                                = var.replicas                                    # How many replicas you want
      "solrOptions.javaMemory"                                                  = var.solrJavaMem                                 # How much memory to give each replica
      "solrOptions.security.authenticationType"                                 = "Basic"
      # TODO: Create a secret unique to each provisioned instance (this may not be necessary)
      # "solrOptions.security.basicAuthSecret"                                    = kubernetes_secret.operator_auth.metadata[0].name
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
      kubectl --kubeconfig <(echo $KUBECONFIG | base64 -d) wait --for=condition=ready --timeout=3600s -n ${data.kubernetes_namespace.namespace.id} pod -l solr-cloud=${local.cloud_name}
    EOF
  }

}

