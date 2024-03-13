# =============================================================================
# General variables
# =============================================================================
variable "prefix" {
  type        = string
  description = "Prefix used for resources to ensure unique naming."
}

# =============================================================================
# AWS variables
# =============================================================================
variable "region" {
  type        = string
  description = "AWS region where the resources will be deployed."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
}

variable "public_subnets_cidr" {
  type        = list(string)
  description = "List of CIDR blocks for public subnets."
}

variable "private_subnet_pair" {
  type        = list(string)
  description = "List of CIDR blocks for private subnets."
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to all resources."
}

# =============================================================================
# Databricks variables
# =============================================================================
variable "databricks_account_id" {
  type        = string
  description = "The Databricks account ID for cross-account access."
}
