# =============================================================================
# Configure workspace catalog and admin group for domain1
# =============================================================================
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

# =============================================================================
# Create a serverless SQL endpoint for minimal usage
# =============================================================================
resource "databricks_sql_endpoint" "serverless_minimal" {
  provider                  = databricks.domain1
  name                      = "serverless_sql_endpoint_minimal"
  cluster_size              = "2X-Small"
  auto_stop_mins            = 5
  enable_serverless_compute = true
}

# =============================================================================
# Activate the system billing schema
# =============================================================================
resource "databricks_system_schema" "billing" {
  provider = databricks.domain1
  schema   = "billing"
}

# =============================================================================
# Create a schema for hub_schema in the workspace catalog
# =============================================================================
resource "databricks_schema" "hub_schema" {
  provider     = databricks.domain1
  name         = "hub_schema"
  catalog_name = module.workspace_catalog1.databricks_catalog_id
}

# =============================================================================
# Create views for system billing usage for each domain
# =============================================================================
resource "databricks_sql_table" "view_system_billing_usage_domain" {
  provider        = databricks.domain1
  for_each        = { for domain in var.domains : domain.domain_name => domain }
  name            = format("view_system_billing_usage_%s", each.value.domain_name)
  catalog_name    = module.workspace_catalog1.databricks_catalog_id
  schema_name     = databricks_schema.hub_schema.name
  table_type      = "VIEW"
  warehouse_id    = databricks_sql_endpoint.serverless_minimal.id
  view_definition = format("SELECT * FROM system.billing.usage WHERE workspace_id = '%s'", each.value.workspace_id)
}
