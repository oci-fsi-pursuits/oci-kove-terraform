output "vcn_id" {
  value       = oci_core_virtual_network.this.id
  description = "VCN OCID."
}

output "vcn_cidr_block" {
  value       = oci_core_virtual_network.this.cidr_block
  description = "VCN CIDR."
}

output "public_route_table_id" {
  value       = oci_core_route_table.public.id
  description = "Public route table (Internet gateway)."
}

output "private_route_table_id" {
  value       = oci_core_route_table.private.id
  description = "Private route table (NAT)."
}

output "public_subnet_id" {
  value       = oci_core_subnet.public.id
  description = "Public subnet OCID."
}

output "management_subnet_id" {
  value       = oci_core_subnet.management.id
  description = "Management subnet OCID."
}

output "rdma_subnet_id" {
  value       = oci_core_subnet.rdma.id
  description = "RDMA / BM subnet OCID."
}

output "public_subnet_availability_domain" {
  value       = oci_core_subnet.public.availability_domain
  description = "AD name for the public subnet."
}

output "management_subnet_availability_domain" {
  value       = oci_core_subnet.management.availability_domain
  description = "AD name for the management subnet."
}

output "rdma_subnet_availability_domain" {
  value       = oci_core_subnet.rdma.availability_domain
  description = "AD name for the RDMA subnet."
}
