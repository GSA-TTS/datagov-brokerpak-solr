variable "server" { type = string }
variable "cluster_ca_certificate" { type = string }
variable "token" { type = string }
variable "namespace" { type = string }

variable "replicas" { type = number }
variable "solrImageTag" { type = string }
variable "solrJavaMem" { type = string }

variable "cloud_name" {
  type = string
  description = "The name of the cloud to create (used only for demo purposes)"
  default = ""
}
