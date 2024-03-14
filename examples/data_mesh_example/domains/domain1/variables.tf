variable "region" {
  type = string
}

variable "domain1_ws" {
  type = object({
    prefix       = string
    url          = string
    token        = string
    catalog_name = string
  })
}
