variable "databricks_account_id" {}
variable "databricks_client_id" {}
variable "databricks_client_secret" {}
variable "databricks_admin_user_id" {}
variable "databricks_workspace_id" {}

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

provider "databricks" {
  account_id = var.databricks_account_id
}

# =============================================================================
# Pattern 1: Assigning permissions to a user
# =============================================================================
resource "databricks_mws_permission_assignment" "admin_user" {
  provider     = databricks.mws
  workspace_id = var.databricks_workspace_id
  principal_id = var.databricks_admin_user_id
  permissions  = ["ADMIN"]
}

# =============================================================================
# Pattern 2: Assigning permissions to a group
# =============================================================================
resource "databricks_group" "group1" {
  provider         = databricks.mws
  display_name     = "test-group-1"
  workspace_access = true
}

resource "databricks_mws_permission_assignment" "group1" {
  provider     = databricks.mws
  workspace_id = var.databricks_workspace_id
  principal_id = databricks_group.group1.id
  permissions  = ["USER"]
}

resource "databricks_user" "user1" {
  provider  = databricks.mws
  user_name = "me@example.com"
}

resource "databricks_group_member" "user1" {
  provider  = databricks.mws
  group_id  = databricks_group.group1.id
  member_id = databricks_user.user1.id
}
