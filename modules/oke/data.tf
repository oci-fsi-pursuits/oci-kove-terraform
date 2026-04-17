data "oci_containerengine_cluster_option" "cluster" {
  cluster_option_id = "all"
}

data "oci_containerengine_node_pool_option" "node_pool_all" {
  compartment_id      = var.compartment_id
  node_pool_option_id = "all"
}

data "oci_containerengine_node_pool_option" "node_pool_cluster" {
  compartment_id      = var.compartment_id
  node_pool_option_id = oci_containerengine_cluster.this.id
}
