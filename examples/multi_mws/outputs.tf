output "databricks_workspaces_details" {
  value = [for key, ws in module.aws_databricks_mws : {
    databricks_workspace_url   = ws.databricks_workspace_url
    databricks_workspace_token = ws.databricks_workspace_token
  }]
  sensitive = true
}
