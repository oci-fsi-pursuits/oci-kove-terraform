# Cluster Placement Group — created before BM instances (see depends_on on oci_core_instance.bm_nodes).
resource "oci_cluster_placement_groups_cluster_placement_group" "bm_rdma" {
  count = var.cluster_placement_group_enabled ? 1 : 0

  availability_domain          = local.cluster_ad
  cluster_placement_group_type = var.cluster_placement_group_type
  compartment_id               = var.compartment_ocid
  description                  = trimspace(var.cluster_placement_group_description) != "" ? trimspace(var.cluster_placement_group_description) : "RDMA bare metal placement for ${local.name_prefix}"
  name                         = trimspace(var.cluster_placement_group_name) != "" ? trimspace(var.cluster_placement_group_name) : "${local.name_prefix}-rdma-cpg"
  defined_tags                 = local.common_tags
}
