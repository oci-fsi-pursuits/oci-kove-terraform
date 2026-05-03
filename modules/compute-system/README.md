# Compute-System Module

Creates the optional single BM node labeled `compute-system`. The root module enables it by default with `enable_compute_system = true`.

Behavior:

- Default: creates one standalone BM in the private subnet.
- If `enable_cluster_network_autoscaling_mode = true`, this module creates a dedicated compute-system cluster network backed by an instance pool.
- Optional autoscaling can be enabled in cluster-network mode with the `cluster_network_*` autoscaling inputs.
- The image is the same resolved BM image used by RDMA memory nodes: `bm_node_custom_image_ocid` when set, otherwise `rhel8_10_image_ocid`.
- Display names use the shortened role `compute`, for example `kove-prod-compute-1`.
- Resources use OCI defined tags from `modules/labels`.
