variable "region" {
  type = string
}

variable "databricks_ws1" {
  type = object({
    prefix = string
    url    = string
    token  = string
  })
}

variable "databricks_ws2" {
  type = object({
    prefix = string
    url    = string
    token  = string
  })
}
