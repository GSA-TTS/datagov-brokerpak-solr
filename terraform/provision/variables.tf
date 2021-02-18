variable "server" { type = string }
variable "cluster_ca_certificate" { type = string }
variable "token" { type = string }
variable "namespace" { type = string }

variable "replicas" { type = number }
variable "solrImageTag" { type = string }
variable "solrJavaMem" { type = string }

variable "cloud_name" { type = string }
variable "domain_name" { type = string }
variable labels { type = map }

locals {
  cloud_name = "solr-${substr(sha256(var.cloud_name), 0, 16)}"
}