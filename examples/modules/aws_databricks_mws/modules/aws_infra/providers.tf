terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    databricks = {
      source = "databricks/databricks"
    }
  }
}

provider "aws" {
  region = var.region
}
