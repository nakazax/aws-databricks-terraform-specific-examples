module "workspace_catalog1" {
  source = "../modules/workspace_catalog"
  providers = {
    aws        = aws
    databricks = databricks.domain1
  }
  prefix       = var.domain1_ws.prefix
  catalog_name = var.domain1_ws.catalog_name
}
