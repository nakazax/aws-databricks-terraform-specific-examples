module "workspace_catalog1" {
  source = "./modules/workspace_catalog"
  providers = {
    databricks = databricks.ws1
  }
  prefix = var.databricks_ws1.prefix
}

module "workspace_catalog2" {
  source = "./modules/workspace_catalog"
  providers = {
    databricks = databricks.ws2
  }
  prefix = var.databricks_ws2.prefix
}
