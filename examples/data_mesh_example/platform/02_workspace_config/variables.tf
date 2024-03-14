variable "databricks_metastore_id" {
  type = string
}

variable "domain1" {
  type = object({
    admin_group_name = string
    token            = string
    url              = string
  })
}

variable "domain2" {
  type = object({
    admin_group_name = string
    token            = string
    url              = string
  })
}
