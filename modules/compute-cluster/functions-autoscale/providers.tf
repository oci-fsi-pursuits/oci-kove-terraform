provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  region       = var.region
}

provider "oci" {
  alias        = "home"
  tenancy_ocid = var.tenancy_ocid
  region       = var.identity_home_region
}
