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

output "private_subnet_id" {
  value       = oci_core_subnet.private.id
  description = "Private subnet OCID."
}

output "public_subnet_availability_domain" {
  value       = oci_core_subnet.public.availability_domain
  description = "AD name for the public subnet."
}

output "private_subnet_availability_domain" {
  value       = oci_core_subnet.private.availability_domain
  description = "AD name for the private subnet."
}
