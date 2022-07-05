
variable "instance_name" {
  type        = string
  description = "Unique ID to separate solr instanceresources"
}

variable "region" {
  type        = string
  description = "region to create solr ecs cluster"
  default     = "us-west-2"
}

variable "labels" {
  type    = map(any)
  default = {}
}

variable "zone" {
  type        = string
  description = "DNS Zone to host Solr service"
}

variable "solrImageRepo" {
  type        = string
  description = "Repository for the Solr Docker image to use, defaults to docker.io/solr"
  default     = "ghcr.io/gsa/catalog.data.gov.solr"
}

variable "solrImageTag" {
  type        = string
  description = "Tag for the Solr Docker image to use, defaults to 8.6. See https://hub.docker.com/_/solr?tab=tags (or your configured solrImageRepo) for options"
  default     = "8-stunnel-root"
}

variable "solrMem" {
  type        = number
  description = "How much memory to request for each replica (default is '12G')"
  default     = 12288
}

variable "solrCpu" {
  type        = number
  description = "How much vCPU to request for each replica (default is '2048' aka '2 vCPUs')"
  default     = 2048
}

variable "setupLink" {
  type        = string
  description = "The Solr setup file for initialization of cores/authentication/et cetera..."
  default     = "https://raw.githubusercontent.com/GSA/catalog.data.gov/main/solr/solr_setup.sh"
}

variable "efsProvisionedThroughput" {
  type        = number
  description = "The throughput, measured in MiB/s, that you want to provision for the file system"
  default     = 1
}
