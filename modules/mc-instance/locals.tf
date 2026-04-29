locals {
  labels_stack_name = "${var.kove_stack_name}-mc"

  ad_name = data.oci_identity_availability_domains.ads.availability_domains[0].name
  ad_used = trimspace(var.availability_domain) != "" ? trimspace(var.availability_domain) : local.ad_name

  deployment_mode = trimspace(var.deployment_mode)

  default_cloud_init_path = "${path.module}/cloud_init/mc-host.yaml.tpl"
  cloud_init_src_path     = trimspace(var.cloud_init_template_path) != "" ? trimspace(var.cloud_init_template_path) : local.default_cloud_init_path

  rendered_user_data = replace(replace(
    templatefile(local.cloud_init_src_path, {
      setup_script_path           = var.setup_script_path
      guest_vm_name               = var.guest_vm_name
      guest_disk_path             = var.guest_disk_path
      guest_memory_mb             = tostring(var.guest_memory_mb)
      guest_vcpus                 = tostring(var.guest_vcpus)
      secondary_vnic_interface    = var.secondary_vnic_interface
      offline_repo_tarball_url    = var.offline_repo_tarball_url
      offline_repo_tarball_sha256 = var.offline_repo_tarball_sha256
      offline_rpm_packages        = var.offline_rpm_packages
    }),
    "\r\n", "\n"),
  "\r", "\n")

  user_data_b64 = base64encode(local.rendered_user_data)

  resolved_custom_image_id = trimspace(var.custom_image_ocid)
  resolved_base_image_id = trimspace(var.base_image_ocid) != "" ? trimspace(var.base_image_ocid) : (
    length(data.oci_core_images.ol8_flex) > 0 && length(data.oci_core_images.ol8_flex[0].images) > 0 ? data.oci_core_images.ol8_flex[0].images[0].id : ""
  )

  source_image_id = local.deployment_mode == "custom_image" ? local.resolved_custom_image_id : local.resolved_base_image_id

  instance_display_name = "${module.labels.name_prefix}-${var.instance_name_suffix}"
  hostname_label = trimspace(var.hostname_label) != "" ? trimspace(var.hostname_label) : (
    length(module.labels.name_prefix) > 11 ? "${substr(module.labels.name_prefix, 0, 11)}mc" : "${module.labels.name_prefix}mc"
  )
}
