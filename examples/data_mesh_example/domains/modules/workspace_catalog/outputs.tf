output "databricks_storage_credential_id" {
  value = databricks_storage_credential.external.id
}

output "databricks_external_location_id" {
  value = databricks_external_location.this.id
}

output "databricks_catalog_id" {
  value = databricks_catalog.this.id
}
