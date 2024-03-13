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
  alias = "workspace1"
  host  = var.databricks_workspaces1.databricks_workspace_url
  token = var.databricks_workspaces1.databricks_workspace_token
}

provider "databricks" {
  alias = "workspace2"
  host  = var.databricks_workspaces2.databricks_workspace_url
  token = var.databricks_workspaces2.databricks_workspace_token
}
