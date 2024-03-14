terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
  }
}

provider "databricks" {
  alias = "domain1"
  host  = var.domain1_ws.url
  token = var.domain1_ws.token
}

provider "databricks" {
  alias = "domain2"
  host  = var.domain1_ws.url
  token = var.domain1_ws.token
}
