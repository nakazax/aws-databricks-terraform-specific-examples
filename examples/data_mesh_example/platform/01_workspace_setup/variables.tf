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
  type        = string
  default     = ""
  description = <<-EOT
    If provided, skip creating a new metastore and assign the existing one to the workspace.
    Note that the Databricks service principal that executes this Terraform script must be a member of the admin group of the existing metastore.
  EOT
}

variable "databricks_account_admin_group_name" {
  type = string
}

variable "databricks_account_admin_principal_ids" {
  type = set(string)
}

variable "databricks_workspaces" {
  type = map(object({
    prefix                     = string
    vpc_cidr                   = string
    public_subnets_cidr        = list(string)
    private_subnet_pair        = list(string)
    tags                       = map(string)
    workspace_admin_group_name = string
    workspace_admin_user_ids   = set(string)
  }))
}
