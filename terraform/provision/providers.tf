provider "kubernetes" {
  host                   = var.server
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  token                  = base64decode(var.token)
  load_config_file       = false
  version = "~> 1.13.3"
}

provider "helm" {
  kubernetes {
    host                   = var.server
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
    token                  = base64decode(var.token)
    load_config_file       = false
  }
  version = "1.2.0"
}
