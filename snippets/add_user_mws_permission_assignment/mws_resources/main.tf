# mws_resources/main.tf as the child module - This module have resources that use the databricks.mws provider
terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
  }
}

variable "workspace_id" { }
variable "principal_id" { }

resource "databricks_mws_permission_assignment" "this" {
  principal_id = var.principal_id
  workspace_id = var.workspace_id
  permissions  = ["USER"]
}
