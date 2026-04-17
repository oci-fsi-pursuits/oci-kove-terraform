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

variable "bm_node_image_ocid" {
  type        = string
  description = "BM image OCID used by the RDMA stack."
}

variable "rdma_deployment_mode" {
  type        = string
  description = "compute_cluster or cluster_network."
  default     = "compute_cluster"
}

variable "management_shape" {
  type    = string
  default = "VM.Standard.E6.Flex"
}

variable "management_ocpus" {
  type    = number
  default = 2
}

variable "management_memory_gbs" {
  type    = number
  default = 16
}

variable "management_image_ocid" {
  type        = string
  default     = ""
  description = "Optional custom image for the management controller."
}

variable "management_secondary_vnic_enabled" {
  type    = bool
  default = false
}

variable "management_secondary_vnic_subnet_id" {
  type    = string
  default = ""
}

variable "management_secondary_vnic_private_ip" {
  type    = string
  default = ""
}

variable "kove_namespace" {
  type    = string
  default = "kove"
}

variable "kove_environment" {
  type    = string
  default = "dev"
}

variable "kove_stack_name" {
  type    = string
  default = "rdma"
}
