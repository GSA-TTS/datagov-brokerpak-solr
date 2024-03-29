terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.63"
    }
    template = {
      source = "hashicorp/template"
    }
  }
  required_version = "~> 1.1"
}

provider "aws" {
  region = "us-west-2"
}

# A separate provider for creating KMS keys in the us-east-1 region, which is required for DNSSEC.
# See https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/dns-configuring-dnssec-cmk-requirements.html
provider "aws" {
  alias  = "dnssec-key-provider"
  region = "us-east-1"
}
