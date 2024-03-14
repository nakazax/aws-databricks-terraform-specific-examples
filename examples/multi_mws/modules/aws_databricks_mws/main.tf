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
resource "time_sleep" "wait_iam_role" {
  create_duration = "10s"
  depends_on      = [module.aws_infra.cross_account_role_arn]
}

resource "databricks_mws_credentials" "this" {
  credentials_name = "${local.prefix}-creds"
  role_arn         = module.aws_infra.cross_account_role_arn
  depends_on       = [time_sleep.wait_iam_role]
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

resource "databricks_metastore_assignment" "this" {
  metastore_id = var.databricks_metastore_id
  workspace_id = databricks_mws_workspaces.this.workspace_id
}

resource "databricks_group" "workspace_admin" {
  display_name     = var.workspace_admin_group_name
  workspace_access = true
}

# Work around to wait for the workspace to be ready for permission assignment
resource "time_sleep" "wait_metastore_assignment" {
  create_duration = "10s"
  depends_on      = [databricks_metastore_assignment.this]
}

resource "databricks_mws_permission_assignment" "workspace_admin" {
  workspace_id = databricks_mws_workspaces.this.workspace_id
  principal_id = databricks_group.workspace_admin.id
  permissions  = ["ADMIN"]
  depends_on   = [time_sleep.wait_metastore_assignment]
}

resource "databricks_group_member" "admin_user" {
  for_each  = toset(var.workspace_admin_user_ids)
  group_id  = databricks_group.workspace_admin.id
  member_id = each.value
}
