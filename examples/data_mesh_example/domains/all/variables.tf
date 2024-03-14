variable "databricks_metastore_id" {
  type = string
}

variable "domain1_ws" {
  type = object({
    prefix           = string
    url              = string
    token            = string
    admin_group_name = string
  })
}

variable "domain2_ws" {
  type = object({
    prefix           = string
    url              = string
    token            = string
    admin_group_name = string
  })
}
