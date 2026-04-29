data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_vcns" "existing_vcns" {
  compartment_id = var.compartment_ocid
}

data "oci_core_subnet" "existing_public" {
  count     = var.use_existing_vcn ? 1 : 0
  subnet_id = var.existing_public_subnet_id
}

data "oci_core_subnet" "existing_private" {
  count     = var.use_existing_vcn ? 1 : 0
  subnet_id = var.existing_private_subnet_id
}

data "oci_core_cluster_network_instances" "rdma" {
  count = local.use_cluster_network_mode ? 1 : 0

  cluster_network_id = oci_core_cluster_network.rdma[0].id
  compartment_id     = var.compartment_ocid
}

data "oci_core_instance" "cluster_network_instances" {
  # Use the configured memory node count (known during plan) so Terraform can
  # build the graph without depending on apply-time discovered instance lists.
  count = local.use_cluster_network_mode ? var.memory_node_count : 0

  instance_id = data.oci_core_cluster_network_instances.rdma[0].instances[count.index]["id"]
}

data "oci_core_images" "ol8_flex" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard.E6.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}
