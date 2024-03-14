variable "databricks_metastore_id" {
  type = string
}

variable "domain1" {
  type = object({
    url              = string
    token            = string
    admin_group_name = string
  })
}

variable "domain2" {
  type = object({
    url              = string
    token            = string
    admin_group_name = string
  })
}
