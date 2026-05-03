variable "compartment_id" {
  type        = string
  description = "Compartment for VCN and networking resources."
}

variable "vcn_cidr_block" {
  type        = string
  description = "VCN CIDR. Subnets use /24 at indices 1 (public), 2 (private) under a /16-style layout."
}

variable "private_subnet_name_prefix" {
  type        = string
  description = "Optional prefix added to the private subnet display name."
  default     = ""
}

variable "name_prefix" {
  type        = string
  description = "Prefix for display_name on all resources (e.g. kove-dev-rdma)."
}

variable "defined_tags" {
  type        = map(string)
  description = "Tags applied to each resource."
  default     = {}
}

variable "ssh_ingress_cidr" {
  type        = string
  description = "CIDR allowed to SSH (22) and optional HPC UI ports on the public subnet security list."
  default     = "0.0.0.0/0"
}

variable "public_ingress_hpc_ui_ports" {
  type        = bool
  description = "Allow TCP 3000 and 5000 from ssh_ingress_cidr on the public security list."
  default     = true
}

variable "private_subnet_ssh_sources_extras" {
  type        = string
  description = "Comma-separated extra CIDRs for SSH to private subnets (in addition to VCN CIDR)."
  default     = ""
}
