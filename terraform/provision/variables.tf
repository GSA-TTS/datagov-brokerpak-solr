
variable "instance_name" {
  type = string
  description = "Unique ID to separate solr instanceresources"
}

variable "region" {
  type        = string
  description = "region to create solr ecs cluster"
  default = "us-west-2"
}

variable "labels" {
  type    = map(any)
  default = {}
}

variable "zone" {
  type = string
  description = "DNS Zone to host Solr service"
}
