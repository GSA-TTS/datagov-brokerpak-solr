
# Ingress should be assumed available of whatever k8s provider is passed in, but
# since we're only running in Docker Desktop for now, we'll just create it.
resource "kubernetes_namespace" "nginx-ingress" {
  metadata {
    name = "nginx-ingress"
  }
}

resource "helm_release" "ingress" {
  name            = "ingress"
  chart           = "nginx-ingress"
  repository      = "https://helm.nginx.com/stable"
  namespace       = "nginx-ingress"
  cleanup_on_fail = "true"
  atomic          = "true"

}

