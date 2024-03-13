output "databricks_workspaces_details" {
  value = [for key, ws in module.aws_databricks_mws : {
    url   = ws.databricks_workspace_url
    token = ws.databricks_workspace_token
  }]
  sensitive = true
}
