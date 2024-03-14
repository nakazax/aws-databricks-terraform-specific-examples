terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    databricks = {
      source = "databricks/databricks"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "databricks" {
  alias = "domain1"
  host  = var.domain1_ws.url
  token = var.domain1_ws.token
}
