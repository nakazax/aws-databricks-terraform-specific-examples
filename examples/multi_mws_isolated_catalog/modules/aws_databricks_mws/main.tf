resource "random_string" "naming" {
  special = false
  upper   = false
  length  = 6
}

locals {
  prefix = var.prefix != "" ? var.prefix : "demo${random_string.naming.result}"
}

module "aws_infra" {
  source = "./modules/aws_infra"

  prefix                = local.prefix
  region                = var.region
  vpc_cidr              = var.vpc_cidr
  public_subnets_cidr   = var.public_subnets_cidr
  private_subnet_pair   = var.private_subnet_pair
  tags                  = var.tags
  databricks_account_id = var.databricks_account_id
}

# Work around to wait for the role to be created
resource "time_sleep" "wait" {
  create_duration = "10s"
  depends_on      = [module.aws_infra.cross_account_role_arn]
}

resource "databricks_mws_credentials" "this" {
  credentials_name = "${local.prefix}-creds"
  role_arn         = module.aws_infra.cross_account_role_arn
  depends_on       = [time_sleep.wait]
}

resource "databricks_mws_storage_configurations" "this" {
  account_id                 = var.databricks_account_id
  storage_configuration_name = "${local.prefix}-storage"
  bucket_name                = module.aws_infra.root_storage_bucket_name
}

resource "databricks_mws_networks" "this" {
  account_id         = var.databricks_account_id
  network_name       = "${local.prefix}-network"
  vpc_id             = module.aws_infra.vpc_id
  subnet_ids         = module.aws_infra.private_subnet_ids
  security_group_ids = module.aws_infra.security_group_ids
}

resource "databricks_mws_workspaces" "this" {
  account_id     = var.databricks_account_id
  workspace_name = local.prefix
  aws_region     = var.region

  credentials_id           = databricks_mws_credentials.this.credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this.storage_configuration_id
  network_id               = databricks_mws_networks.this.network_id

  token {}
}

# (Option) If the metastore id is provided, create the metastore assignment to workspace, otherwise skip it
resource "databricks_metastore_assignment" "this" {
  count        = var.databricks_metastore_id != "" ? 1 : 0
  metastore_id = var.databricks_metastore_id
  workspace_id = databricks_mws_workspaces.this.workspace_id
}

# (Option) If the admin principal id is provided, create the permission assignment to workspace, otherwise skip it
# Metastore assignment is required for the permission assignment
resource "databricks_mws_permission_assignment" "admin_user" {
  count        = var.databricks_admin_principal_id != "" && var.databricks_metastore_id != "" ? 1 : 0
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = var.databricks_admin_principal_id
  permissions  = ["ADMIN"]
  depends_on   = [databricks_metastore_assignment.this]
}
