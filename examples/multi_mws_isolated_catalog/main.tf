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
  databricks_metastore_id = var.databricks_metastore_id

  # Workspace specific variables
  prefix                        = each.value.prefix
  vpc_cidr                      = each.value.vpc_cidr
  public_subnets_cidr           = each.value.public_subnets_cidr
  private_subnet_pair           = each.value.private_subnet_pair
  tags                          = each.value.tags
  databricks_admin_principal_id = each.value.databricks_admin_principal_id
}
