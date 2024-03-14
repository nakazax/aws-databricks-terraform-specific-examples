terraform {
  required_providers {
    databricks = {
      source = "databricks/databricks"
    }
  }
}

provider "databricks" {
  alias = "domain1"
  host  = var.domain1.url
  token = var.domain1.token
}

provider "databricks" {
  alias = "domain2"
  host  = var.domain2.url
  token = var.domain2.token
}
