variable "databricks_account_id" {}
variable "databricks_client_id" {}
variable "databricks_client_secret" {}

terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
  }
}

provider "databricks" {
  alias         = "mws"
  host          = "https://accounts.cloud.databricks.com"
  account_id    = var.databricks_account_id
  client_id     = var.databricks_client_id
  client_secret = var.databricks_client_secret
}

resource "databricks_user" "me" {
  provider                 = databricks.mws
  user_name                = "me@example.com"
  disable_as_user_deletion = false
}
