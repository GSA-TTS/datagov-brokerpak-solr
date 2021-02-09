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

