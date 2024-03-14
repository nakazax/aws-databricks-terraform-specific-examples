output "databricks_metastore_id" {
  value = local.metastore_id
}

output "databricks_workspaces_details" {
  value = [for key, ws in module.aws_databricks_mws : {
    databricks_workspace_name             = ws.databricks_workspace_name
    databricks_workspace_url              = ws.databricks_workspace_url
    databricks_workspace_token            = ws.databricks_workspace_token
    databricks_workspace_admin_group_name = ws.databricks_workspace_admin_group_name
  }]
  sensitive = true
}
