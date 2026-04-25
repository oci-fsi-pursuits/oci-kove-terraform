# Production profile: Frankfurt existing VCN + cluster_network + bastion + MC VM host
#
# Fill or confirm these before apply:
# - tenancy_ocid
# - compartment_ocid
# - ssh_public_key
# - availability_domain

tenancy_ocid     = "ocid1.tenancy.oc1..aaaaaaaay7s6icq755xqlytpl33i7ysjzzb2kv3vk3itg5ilsxanrzqmsaha"
region           = "eu-frankfurt-1"
compartment_ocid = "ocid1.compartment.oc1..aaaaaaaaigykop6ta7pgwwjqy3bklwjtphlpipodelhcxfnppzqe6ckjpsxa"

ssh_public_key = <<-EOT
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFxiFvqTs44DeloetWH9hExF4UZDeiH7YKo7a7ioKj3F7OmyyOSFEg2Usogvu4xqisQxvzN0OCezOYq/vzkAJJOMd0iuE0QRMfyiBvwn47aiXzCBW0CKuFbeM2RCuIfvXFbBkoMS0W21ji6vFAxmqeATiy8HIWJyHtv9Bb+flqgmBAjqscFyX2ju7reBOcyJbtTFlRp/gzFurXZ0kMvSSjtseNRhAjtpgFX181h6HgKq0DniJDeAXM19GtOeogemA7SiPv/UncRPIXR9pF4qq6BaMNVU5LUuTfiZKGEMRsoPp8gnvWKFHeib0JTrbSVvsjrplYZ9cL4kRslqwIyJD3 ssh-key-2025-04-07
EOT

kove_namespace    = "kove"
kove_environment  = "prod"
kove_stack_name   = "rdma"
host_label_prefix = "fra"

tags = {
  project = "rdma-platform"
  env     = "prod"
}

# Example format: pILZ:EU-FRANKFURT-1-AD-1
availability_domain = "pILZ:EU-FRANKFURT-1-AD-2"

use_existing_vcn              = true
existing_vcn_id               = "ocid1.vcn.oc1.eu-frankfurt-1.amaaaaaaqx2yg4yabbfaddvm5adms2f5wuz6kvnyei6fl7ox5hyarpjcn7pq"
existing_public_subnet_id     = "ocid1.subnet.oc1.eu-frankfurt-1.aaaaaaaacaungikgpjlfs3g3mrzoa2wpymm2ryvsdijkpgplxuhv3ks6g3qa"
existing_management_subnet_id = "ocid1.subnet.oc1.eu-frankfurt-1.aaaaaaaa6x27p57wk6jaoj7bb7d2gk6dm7t47eog6lsvlpqwwjqmvgjge5vq"
existing_rdma_subnet_id       = "ocid1.subnet.oc1.eu-frankfurt-1.aaaaaaaaz5vs6hmh2oir6xp7zspq2mh46tkkjkpnpk6zugzxdmizwitedqwq"

# RDMA / BM plane
bm_node_image_ocid   = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaneewfnt24l6v4fncr4gljndelmiaqdlqzcyt4hbolyhzoqsj2eza"
rdma_deployment_mode = "cluster_network"
memory_node_count    = 2

# Cluster-network autoscaling
cluster_network_enable_autoscaling                      = true
cluster_network_autoscaling_min_nodes                   = 2
cluster_network_autoscaling_max_nodes                   = 8
cluster_network_autoscaling_initial_nodes               = 2
cluster_network_autoscaling_cooldown_seconds            = 300
cluster_network_autoscaling_scale_out_threshold_percent = 80
cluster_network_autoscaling_scale_in_threshold_percent  = 30
cluster_network_autoscaling_scale_out_by                = 1
cluster_network_autoscaling_scale_in_by                 = 1

use_compute_agent              = true
bm_generic_platform_config     = false
bm_capacity_reservation_id     = ""
bm_boot_volume_size_gbs        = 120
cluster_network_create_timeout = "2h"
bm_imds_ssh_key_bootstrap      = true
create_bm_console_connections  = false

# Role naming
compute_system_name = "compute-system"
xpd_name            = "xpd"

# Bastion
enable_bastion = true

# MC host (separate instance)
enable_management_instance  = false
enable_mc_instance          = true
mc_shape                    = "VM.Standard3.Flex"
mc_ocpus                    = 3
mc_memory_gbs               = 32
mc_assign_public_ip         = false
mc_subnet_id                = "ocid1.subnet.oc1.eu-frankfurt-1.aaaaaaaa6x27p57wk6jaoj7bb7d2gk6dm7t47eog6lsvlpqwwjqmvgjge5vq"
# Optional override. Empty defaults to same subnet as mc_subnet_id/primary VNIC.
# mc_secondary_vnic_subnet_id = "ocid1.subnet.oc1.eu-frankfurt-1.aaaaaaaaz5vs6hmh2oir6xp7zspq2mh46tkkjkpnpk6zugzxdmizwitedqwq"
# mc_secondary_vnic_private_ip = "10.0.2.58"
mc_secondary_vnic_interface = "eth1"

# Cloud-init is applied in all MC modes.
mc_deployment_mode   = "custom_image"
mc_custom_image_ocid = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaasagdlct7ew52dfkw6otax7jqqdb4grjlcqu6w2oqs4nlst4jreq"

# Alternate mode (comment out custom_image lines and enable these if needed):
# mc_deployment_mode = "cloud_init_setup"
# mc_base_image_ocid = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaaneewfnt24l6v4fncr4gljndelmiaqdlqzcyt4hbolyhzoqsj2eza"
