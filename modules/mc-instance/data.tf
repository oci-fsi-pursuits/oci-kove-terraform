data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_ocid
}

data "oci_core_images" "ol8_flex" {
  count = trimspace(var.base_image_ocid) == "" && trimspace(var.deployment_mode) == "cloud_init_setup" ? 1 : 0

  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}
