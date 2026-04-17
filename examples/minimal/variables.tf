variable "namespace" {
  type    = string
  default = "kove"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "stack_name" {
  type    = string
  default = "demo"
}

variable "additional_tags" {
  type    = map(string)
  default = {}
}

variable "include_managed_by_tag" {
  type    = bool
  default = true
}
