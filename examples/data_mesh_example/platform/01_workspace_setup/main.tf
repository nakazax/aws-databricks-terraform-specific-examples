# =============================================================================
# Create admin group
# Ref. https://registry.terraform.io/providers/databricks/databricks/latest/docs/guides/unity-catalog
# =============================================================================
resource "databricks_group" "account_admin" {
  provider     = databricks.mws
  display_name = var.databricks_account_admin_group_name
}

resource "databricks_group_member" "account_admin" {
  provider  = databricks.mws
  for_each  = toset(concat(var.databricks_account_admin_user_ids, var.databricks_account_admin_service_principal_ids))
  group_id  = databricks_group.account_admin.id
  member_id = each.value
}

resource "databricks_user_role" "account_admin" {
  provider = databricks.mws
  for_each = toset(var.databricks_account_admin_user_ids)
  user_id  = each.value
  role     = "account_admin"
}

resource "databricks_service_principal_role" "account_admin" {
  provider             = databricks.mws
  for_each             = toset(var.databricks_account_admin_service_principal_ids)
  service_principal_id = each.value
  role                 = "account_admin"
}

# =============================================================================
# Create Unity Catalog Metastore
# Ref. https://registry.terraform.io/providers/databricks/databricks/latest/docs/guides/unity-catalog
# =============================================================================
# If the provided metastore id is empty, create a new metastore
resource "databricks_metastore" "this" {
  count         = var.databricks_metastore_id == "" ? 1 : 0
  provider      = databricks.mws
  name          = "primary"
  owner         = databricks_group.account_admin.display_name
  region        = var.region
  force_destroy = true
}

# =============================================================================
# Create Databricks workspaces
# Ref. https://registry.terraform.io/providers/databricks/databricks/latest/docs/guides/aws-workspace
# =============================================================================
locals {
  metastore_id = var.databricks_metastore_id == "" ? databricks_metastore.this[0].id : var.databricks_metastore_id
}

module "aws_databricks_mws" {
  source = "./modules/aws_databricks_mws"
  providers = {
    aws        = aws
    databricks = databricks.mws
  }

  for_each = var.databricks_workspaces

  # Common variables for all workspaces
  region                  = var.region
  databricks_account_id   = var.databricks_account_id
  databricks_metastore_id = local.metastore_id

  # Workspace specific variables
  prefix                     = each.value.prefix
  vpc_cidr                   = each.value.vpc_cidr
  public_subnets_cidr        = each.value.public_subnets_cidr
  private_subnet_pair        = each.value.private_subnet_pair
  tags                       = each.value.tags
  workspace_admin_group_name = each.value.workspace_admin_group_name
  workspace_admin_user_ids   = each.value.workspace_admin_user_ids
}
