variable "tenancy_ocid" {
  type        = string
  description = "OCI tenancy OCID."
}

variable "compartment_ocid" {
  type        = string
  description = "Compartment where the bastion is created."
}

variable "subnet_id" {
  type        = string
  description = "Public subnet OCID for the bastion primary VNIC."
}

variable "availability_domain" {
  type        = string
  description = "Availability domain for the bastion."
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key injected for access."
}

variable "kove_namespace" {
  type        = string
  description = "Short project prefix for names and tags."
  default     = "kove"
}

variable "kove_environment" {
  type        = string
  description = "Environment label."
  default     = "dev"
}

variable "kove_stack_name" {
  type        = string
  description = "Compatibility stack identifier. Not included in default display names."
  default     = "rdma"
}

variable "name_prefix_override" {
  type        = string
  description = "Optional explicit prefix for bastion display_name fields. Empty uses labels default composition."
  default     = ""
}

variable "host_label_prefix" {
  type        = string
  description = "Optional DNS-safe prefix for hostname labels."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Extra defined tag values."
  default     = {}
}

variable "defined_tag_namespace" {
  type        = string
  description = "OCI defined tag namespace used for standard tags."
  default     = "kove"
}

variable "enable_defined_tags" {
  type        = bool
  description = "Apply OCI defined tags to bastion resources."
  default     = false
}

variable "shape" {
  type        = string
  description = "Bastion VM shape."
  default     = "VM.Standard.E6.Flex"
}

variable "ocpus" {
  type        = number
  description = "Bastion OCPUs."
  default     = 2
}

variable "memory_gbs" {
  type        = number
  description = "Bastion memory in GB."
  default     = 16
}

variable "image_ocid" {
  type        = string
  description = "Image OCID for the bastion."
}

variable "assign_public_ip" {
  type        = bool
  description = "Assign a public IP to the bastion primary VNIC."
  default     = true
}
