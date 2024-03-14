# =============================================================================
# General variables
# =============================================================================
variable "prefix" {
  type    = string
  default = ""
}

# =============================================================================
# AWS variables
# =============================================================================
variable "region" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnets_cidr" {
  type = list(string)
}

variable "private_subnet_pair" {
  type = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}

# =============================================================================
# Databricks variables
# =============================================================================
variable "databricks_account_id" {
  type = string
}

variable "databricks_metastore_id" {
  type = string
}

variable "workspace_admin_group_name" {
  type = string
}

variable "workspace_admin_user_ids" {
  type        = set(string)
  default     = []
  description = "If provided, the users will be added to the admin group."
}
