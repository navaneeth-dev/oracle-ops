data "oci_identity_availability_domain" "ad" {
  compartment_id = var.compartment_ocid
  ad_number      = 1
}

resource "oci_core_virtual_network" "talos_vcn" {
  cidr_block     = "10.0.0.0/16"
  compartment_id = var.compartment_ocid
  display_name   = "talos"
  dns_label      = "talos"
  is_ipv6enabled = true
}

resource "oci_core_internet_gateway" "talos_internet_gateway" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id

  display_name = "Internet Gateway"
}

resource "oci_core_nat_gateway" "talos_nodes" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id

  display_name = "NAT Gateway"
}

resource "oci_core_subnet" "nodes" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id
  cidr_block     = "10.0.10.0/24"

  display_name = "nodes"
  dns_label    = "nodes"

  prohibit_internet_ingress = false
  dhcp_options_id           = oci_core_virtual_network.talos_vcn.default_dhcp_options_id
  route_table_id            = oci_core_route_table.internet_routing.id
}

resource "oci_core_subnet" "loadbalancers" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id
  cidr_block     = "10.0.60.0/24"

  display_name = "loadbalancers"
  dns_label    = "loadbalancers"

  prohibit_internet_ingress = true
  route_table_id            = oci_core_route_table.internet_routing.id
  security_list_ids = [oci_core_security_list.loadbalancers_sec_list.id]
  dhcp_options_id           = oci_core_virtual_network.talos_vcn.default_dhcp_options_id
}

resource "oci_core_subnet" "public_lbs" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id
  cidr_block     = "10.0.70.0/24"
  ipv6cidr_block = cidrsubnet(oci_core_virtual_network.talos_vcn.ipv6cidr_blocks[0], 8, 0)

  display_name = "publiclbs"
  dns_label    = "publiclbs"

  prohibit_internet_ingress = false
  route_table_id            = oci_core_route_table.internet_routing.id
  security_list_ids = [oci_core_security_list.public_lbs_sec_list.id]
  dhcp_options_id           = oci_core_virtual_network.talos_vcn.default_dhcp_options_id
}

resource "oci_core_subnet" "bastion" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_virtual_network.talos_vcn.id
  cidr_block     = "10.0.30.0/24"

  display_name = "bastion"
  dns_label    = "bastion"

  prohibit_internet_ingress = true
  route_table_id            = oci_core_route_table.internet_routing.id
  security_list_ids = [oci_core_security_list.bastion_sec_list.id]
  dhcp_options_id           = oci_core_virtual_network.talos_vcn.default_dhcp_options_id
}
