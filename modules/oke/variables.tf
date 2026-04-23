variable "compartment_id" {
  type        = string
  description = "Compartment for OKE resources."
}

variable "region" {
  type        = string
  description = "OCI region used in kubeconfig helper output."
}

variable "name_prefix" {
  type        = string
  description = "Prefix for OKE display_name values (for example kove-dev-oke)."
}

variable "compute_system_name" {
  type        = string
  description = "Role label used in OKE cluster name."
  default     = "compute-system"
}

variable "xpd_name" {
  type        = string
  description = "Role label used in OKE worker node pool name."
  default     = "xpd"
}

variable "vcn_id" {
  type        = string
  description = "VCN OCID for the OKE cluster."
}

variable "endpoint_subnet_id" {
  type        = string
  description = "Subnet OCID for the Kubernetes API endpoint."
}

variable "service_lb_subnet_id" {
  type        = string
  description = "Subnet OCID for OKE service load balancers."
}

variable "worker_subnet_id" {
  type        = string
  description = "Subnet OCID for the worker node pool."
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key injected into worker nodes."
}

variable "availability_domain" {
  type        = string
  description = "Availability domain for worker placement (for example kIdk:US-ASHBURN-AD-1)."
}

variable "kubernetes_version" {
  type        = string
  description = "Optional Kubernetes version (empty = newest supported version)."
  default     = ""
}

variable "public_control_plane_endpoint" {
  type        = bool
  description = "Expose Kubernetes API endpoint publicly."
  default     = true
}

variable "node_pool_shape" {
  type        = string
  description = "Node pool shape. Flex shapes can use node_pool_ocpus and node_pool_memory_gbs."
  default     = "VM.Standard.E6.Flex"
}

variable "node_pool_ocpus" {
  type        = number
  description = "Flex shape OCPUs."
  default     = 2
}

variable "node_pool_memory_gbs" {
  type        = number
  description = "Flex shape memory in GB."
  default     = 16
}

variable "node_pool_size" {
  type        = number
  description = "Worker count for the node pool."
  default     = 3

  validation {
    condition     = var.node_pool_size >= 1 && var.node_pool_size <= 32
    error_message = "node_pool_size must be between 1 and 32."
  }
}

variable "worker_image_id" {
  type        = string
  description = "Optional image OCID for worker nodes (empty = auto-pick compatible image)."
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Freeform tags applied to major OKE resources."
  default     = {}
}
