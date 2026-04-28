variable "compartment_ocid" { type = string }
variable "name_prefix" { type = string }
variable "common_tags" { type = map(string) }
variable "cluster_ad" { type = string }
variable "rdma_subnet_id" { type = string }
variable "compute_system_name" { type = string }
variable "compute_system_hostname" { type = string }
variable "xpd_name" { type = string }

variable "bm_node_shape" { type = string }
variable "bm_node_image_ocid" { type = string }
variable "bm_boot_volume_size_gbs" { type = number }
variable "bm_capacity_reservation_id" { type = string }
variable "bm_generic_platform_config" { type = bool }
variable "bm_smt_enabled" { type = bool }
variable "bm_numa_nodes_per_socket" { type = string }
variable "bm_instance_create_timeout" { type = string }
variable "bm_user_data_b64" { type = string }
variable "cluster_ssh_authorized_keys" { type = string }
variable "use_compute_agent" { type = bool }

variable "memory_node_count" { type = number }
variable "cluster_placement_group_enabled" { type = bool }

variable "cluster_network_enable_autoscaling" { type = bool }
variable "cluster_network_autoscaling_min_nodes" { type = number }
variable "cluster_network_autoscaling_max_nodes" { type = number }
variable "cluster_network_autoscaling_initial_nodes" { type = number }
variable "cluster_network_autoscaling_cooldown_seconds" { type = number }
variable "cluster_network_autoscaling_scale_out_threshold_percent" { type = number }
variable "cluster_network_autoscaling_scale_in_threshold_percent" { type = number }
variable "cluster_network_autoscaling_scale_out_by" { type = number }
variable "cluster_network_autoscaling_scale_in_by" { type = number }
