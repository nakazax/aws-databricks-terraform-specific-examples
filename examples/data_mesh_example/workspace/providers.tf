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
  alias = "ws1"
  host  = var.databricks_ws1.url
  token = var.databricks_ws1.token
}

provider "databricks" {
  alias = "ws2"
  host  = var.databricks_ws2.url
  token = var.databricks_ws2.token
}
