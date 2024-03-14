variable "region" {
  type = string
}

variable "domain1" {
  type = object({
    admin_group_name = string
    catalog_name     = string
    prefix           = string
    token            = string
    url              = string
  })
}
