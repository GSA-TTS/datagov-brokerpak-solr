provider "kubernetes" {
  host                   = var.server
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  token                  = base64decode(var.token)
}

provider "helm" {
  kubernetes {
    host                   = var.server
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
    token                  = base64decode(var.token)
  }
}
