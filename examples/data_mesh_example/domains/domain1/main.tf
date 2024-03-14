module "workspace_catalog1" {
  source = "../modules/workspace_catalog"
  providers = {
    aws        = aws
    databricks = databricks.domain1
  }
  prefix           = var.domain1.prefix
  catalog_name     = var.domain1.catalog_name
  admin_group_name = var.domain1.admin_group_name
}
