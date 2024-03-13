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
  type        = string
  default     = ""
  description = "If provided, the metastore id will be linked to the databricks workspace."
}

variable "databricks_admin_principal_id" {
  type        = string
  default     = ""
  description = "If provided, the admin permission will be assigned to the principal id."
}
