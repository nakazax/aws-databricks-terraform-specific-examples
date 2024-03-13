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
  host  = var.databricks_workspace_url
  token = var.databricks_workspace_token
}
