terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~>2.4"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~>2.7"
    }
    template = {
      source = "hashicorp/template"
    }
  }
  required_version = ">= 1.1"
}
