# Compute-System Module

Creates the optional single BM node labeled `compute-system`. The root module enables it by default with `enable_compute_system = true`.

Behavior:

- In the documented production flow (`cluster_network`), the instance is a standalone BM in the private subnet.
- The image is the same resolved BM image used by RDMA memory nodes: `bm_node_custom_image_ocid` when set, otherwise `rhel8_10_image_ocid`.
