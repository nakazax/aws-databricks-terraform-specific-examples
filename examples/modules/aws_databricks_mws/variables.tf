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
  type    = string
  default = "ap-northeast-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.109.0.0/17"
}

variable "public_subnets_cidr" {
  type    = list(string)
  default = ["10.109.2.0/23"]
}

variable "private_subnet_pair" {
  type    = list(string)
  default = ["10.109.4.0/23", "10.109.6.0/23"]
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

variable "databricks_client_id" {
  type = string
}

variable "databricks_client_secret" {
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
