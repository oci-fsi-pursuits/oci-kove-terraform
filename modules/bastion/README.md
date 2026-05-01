# Bastion Module

Creates the optional public jump host. The root module enables it by default with `enable_bastion = true`.

The image is resolved by the root module:

- `bastion_custom_image_ocid` when set
- otherwise `rhel8_10_image_ocid`
