# Variables
variable "databricks_account_id" {}
variable "databricks_client_id" {}
variable "databricks_client_secret" {}
variable "databricks_workspace_id" {}

# main.tf as the parent module
terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
  }
}

# Default databricks provider
provider "databricks" {
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.databricks_account_id
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}

# Databricks provider with alias mws
provider "databricks" {
  alias         = "mws"
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.databricks_account_id
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}

# This use default databricks provider implicitly
resource "databricks_user" "me" {
  user_name                = "me@example.com"
  disable_as_user_deletion = false
}

# Module for databricks_mws* resources that use the databricks.mws as the provider
module "mws_resources" {
  # Set databricks.mws as the provider for the module
  providers = {
    databricks = databricks.mws
  }
  source       = "./mws_resources"
  principal_id = databricks_user.me.id
  workspace_id = var.databricks_workspace_id
}
