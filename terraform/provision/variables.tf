
variable "region" {
  type        = string
  description = "region to create solr ecs cluster"
  default = "us-west-2"
}

variable "labels" {
  type    = map(any)
  default = {}
}
