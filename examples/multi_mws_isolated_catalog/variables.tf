variable "region" {
  type = string
}

variable "databricks_account_id" {
  type = string
}

variable "databricks_client_id" {
  type = string
}

variable "databricks_client_secret" {
  type = string
}

variable "databricks_metastore_id" {
  type = string
}

variable "databricks_workspaces" {
  type = map(object({
    prefix                     = string
    vpc_cidr                   = string
    public_subnets_cidr        = list(string)
    private_subnet_pair        = list(string)
    tags                       = map(string)
    workspace_admin_group_name = string
    workspace_admin_user_id    = string
  }))
}
