locals {
  private_subnet_ssh_extra_cidrs = compact([for s in split(",", var.private_subnet_ssh_sources_extras) : trimspace(s) if trimspace(s) != ""])

  public_subnet_cidr = cidrsubnet(var.vcn_cidr_block, 8, 1)
  mgmt_subnet_cidr   = cidrsubnet(var.vcn_cidr_block, 8, 2)
  rdma_subnet_cidr   = cidrsubnet(var.vcn_cidr_block, 8, 3)

  dns_safe_prefix = substr(replace(replace(lower(trimspace(var.name_prefix)), "-", ""), "_", ""), 0, 12)
  vcn_dns_label   = length(local.dns_safe_prefix) > 0 ? local.dns_safe_prefix : "rdmaplatform"

  oracle_services_network = data.oci_core_services.oracle_services_network.services[0]
  dhcp_search_domain      = format("%s.oraclevcn.com", local.vcn_dns_label)

  vcn_name           = "${var.name_prefix}-vcn"
  igw_name           = "${var.name_prefix}-igw"
  nat_name           = "${var.name_prefix}-nat"
  public_rt_name     = "${var.name_prefix}-public-rt"
  private_rt_name    = "${var.name_prefix}-private-rt"
  public_sl_name     = "${var.name_prefix}-public-sl"
  private_sl_name    = "${var.name_prefix}-private-sl"
  public_subnet_name = "${var.name_prefix}-public"
  mgmt_subnet_name   = "${var.name_prefix}-mgmt"
  rdma_subnet_name   = "${var.name_prefix}-rdma"
}

resource "oci_core_virtual_network" "this" {
  cidr_block     = var.vcn_cidr_block
  compartment_id = var.compartment_id
  display_name   = local.vcn_name
  dns_label      = substr(local.vcn_dns_label, 0, 15)
  freeform_tags  = var.freeform_tags
}

resource "oci_core_internet_gateway" "this" {
  compartment_id = var.compartment_id
  display_name   = local.igw_name
  enabled        = true
  vcn_id         = oci_core_virtual_network.this.id
  freeform_tags  = var.freeform_tags
}

resource "oci_core_nat_gateway" "this" {
  compartment_id = var.compartment_id
  display_name   = local.nat_name
  vcn_id         = oci_core_virtual_network.this.id
  freeform_tags  = var.freeform_tags
}

resource "oci_core_service_gateway" "this" {
  compartment_id = var.compartment_id
  display_name   = "${var.name_prefix}-service-gw"
  vcn_id         = oci_core_virtual_network.this.id
  freeform_tags  = var.freeform_tags

  services {
    service_id = local.oracle_services_network.id
  }
}

resource "oci_core_dhcp_options" "this" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_virtual_network.this.id
  display_name   = "${var.name_prefix}-dhcp"
  freeform_tags  = var.freeform_tags

  options {
    type        = "DomainNameServer"
    server_type = "VcnLocalPlusInternet"
  }

  options {
    type                = "SearchDomain"
    search_domain_names = [local.dhcp_search_domain]
  }
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  display_name   = local.public_rt_name
  vcn_id         = oci_core_virtual_network.this.id
  freeform_tags  = var.freeform_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.this.id
  }
}

resource "oci_core_route_table" "private" {
  compartment_id = var.compartment_id
  display_name   = local.private_rt_name
  vcn_id         = oci_core_virtual_network.this.id
  freeform_tags  = var.freeform_tags

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.this.id
  }
}

resource "oci_core_security_list" "public" {
  compartment_id = var.compartment_id
  display_name   = local.public_sl_name
  vcn_id         = oci_core_virtual_network.this.id
  freeform_tags  = var.freeform_tags

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "all"
    source   = var.vcn_cidr_block
  }

  ingress_security_rules {
    protocol = "6"
    source   = var.ssh_ingress_cidr
    tcp_options {
      min = 22
      max = 22
    }
  }

  dynamic "ingress_security_rules" {
    for_each = var.public_ingress_hpc_ui_ports ? [3000, 5000] : []
    content {
      protocol = "6"
      source   = var.ssh_ingress_cidr
      tcp_options {
        min = ingress_security_rules.value
        max = ingress_security_rules.value
      }
    }
  }

  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    protocol = "1"
    source   = var.vcn_cidr_block
    icmp_options {
      type = 3
    }
  }
}

resource "oci_core_security_list" "private" {
  compartment_id = var.compartment_id
  display_name   = local.private_sl_name
  vcn_id         = oci_core_virtual_network.this.id
  freeform_tags  = var.freeform_tags

  egress_security_rules {
    protocol    = "all"
    destination = "0.0.0.0/0"
  }

  ingress_security_rules {
    protocol = "all"
    source   = var.vcn_cidr_block
  }

  dynamic "ingress_security_rules" {
    for_each = local.private_subnet_ssh_extra_cidrs
    content {
      protocol = "6"
      source   = ingress_security_rules.value
      tcp_options {
        min = 22
        max = 22
      }
    }
  }

  ingress_security_rules {
    protocol = "1"
    source   = "0.0.0.0/0"
    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    protocol = "1"
    source   = var.vcn_cidr_block
    icmp_options {
      type = 3
    }
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_id
  display_name               = local.public_subnet_name
  vcn_id                     = oci_core_virtual_network.this.id
  cidr_block                 = local.public_subnet_cidr
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.public.id]
  prohibit_public_ip_on_vnic = false
  dns_label                  = "public"
  freeform_tags              = var.freeform_tags
}

resource "oci_core_subnet" "management" {
  compartment_id             = var.compartment_id
  display_name               = local.mgmt_subnet_name
  vcn_id                     = oci_core_virtual_network.this.id
  cidr_block                 = local.mgmt_subnet_cidr
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  dhcp_options_id            = oci_core_dhcp_options.this.id
  prohibit_public_ip_on_vnic = true
  dns_label                  = "mgmt"
  freeform_tags              = var.freeform_tags
}

resource "oci_core_subnet" "rdma" {
  compartment_id             = var.compartment_id
  display_name               = local.rdma_subnet_name
  vcn_id                     = oci_core_virtual_network.this.id
  cidr_block                 = local.rdma_subnet_cidr
  route_table_id             = oci_core_route_table.private.id
  security_list_ids          = [oci_core_security_list.private.id]
  dhcp_options_id            = oci_core_dhcp_options.this.id
  prohibit_public_ip_on_vnic = true
  dns_label                  = "rdma"
  freeform_tags              = var.freeform_tags
}
