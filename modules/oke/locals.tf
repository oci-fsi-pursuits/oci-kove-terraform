locals {
  k8s_versions_sorted = sort(data.oci_containerengine_cluster_option.cluster.kubernetes_versions)
  k8s_version         = trimspace(var.kubernetes_version) != "" ? trimspace(var.kubernetes_version) : local.k8s_versions_sorted[length(local.k8s_versions_sorted) - 1]

  node_image_sources_cluster = [
    for source in coalesce(data.oci_containerengine_node_pool_option.node_pool_cluster.sources, []) :
    source if try(source.source_type, "") == "IMAGE" && try(source.image_id, "") != ""
  ]

  node_image_sources_all = [
    for source in coalesce(data.oci_containerengine_node_pool_option.node_pool_all.sources, []) :
    source if try(source.source_type, "") == "IMAGE" && try(source.image_id, "") != ""
  ]

  node_image_sources = length(local.node_image_sources_cluster) > 0 ? local.node_image_sources_cluster : local.node_image_sources_all

  node_image_sources_x86 = [
    for source in local.node_image_sources :
    source if !can(regex("(?i)aarch64|arm64", coalesce(try(source.source_name, ""), "")))
  ]

  worker_image_id_effective = trimspace(var.worker_image_id) != "" ? trimspace(var.worker_image_id) : try(local.node_image_sources_x86[0].image_id, "")
}
