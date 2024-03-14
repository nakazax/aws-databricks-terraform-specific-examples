# =============================================================================
# Grant metastore privileges to each admin group of the workspaces
# =============================================================================
resource "databricks_grant" "domain1" {
  provider   = databricks.domain1
  metastore  = var.databricks_metastore_id
  principal  = var.domain1_ws.admin_group_name
  privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
}

resource "databricks_grant" "domain2" {
  provider   = databricks.domain2
  metastore  = var.databricks_metastore_id
  principal  = var.domain2_ws.admin_group_name
  privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
}
