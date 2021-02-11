variable "server" { type = string }
variable "cluster_ca_certificate" { type = string }
variable "token" { type = string }
variable "namespace" { type = string }
variable "cloud_name" { type = string }
variable "username" { type = string }
variable "password" { type = string }

locals {
  cloud_name = "solr-${substr(sha256(var.cloud_name), 0, 16)}"
}
