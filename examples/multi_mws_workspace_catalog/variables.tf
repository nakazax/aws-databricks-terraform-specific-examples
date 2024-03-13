variable "region" {
  type = string
}

variable "databricks_workspace1" {
  type = object({
    prefix                     = string
    databricks_workspace_url   = string
    databricks_workspace_token = string
  })
}

variable "databricks_workspace2" {
  type = object({
    prefix                     = string
    databricks_workspace_url   = string
    databricks_workspace_token = string
  })
}
