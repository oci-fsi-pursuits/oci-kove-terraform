variable "tenancy_ocid" {
  type = string
}

variable "region" {
  type = string
}

variable "compartment_ocid" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "availability_domain" {
  type        = string
  description = "Worker node placement AD (for example pILZ:PHX-AD-1)."
}

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
  default = "oke"
}

variable "vcn_cidr_block" {
  type    = string
  default = "10.20.0.0/16"
}

variable "tags" {
  type    = map(string)
  default = {}
}
