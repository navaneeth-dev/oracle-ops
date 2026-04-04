resource "oci_core_vcn" "talos_vcn" {
  compartment_id = var.compartment_id
  cidr_block     = var.vcn_cidr
  display_name   = "${var.cluster_name}-vcn"
  dns_label      = "talos"
}

resource "oci_core_subnet" "talos_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.talos_vcn.id
  cidr_block     = var.subnet_cidr
  display_name   = "${var.cluster_name}-subnet"
  dns_label      = "kubernetes"
  
  # Ensure we have a public IP if needed, although NLB will handle entry
  prohibit_public_ip_on_vnic = false
}

resource "oci_core_internet_gateway" "talos_ig" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.talos_vcn.id
  display_name   = "${var.cluster_name}-ig"
}

resource "oci_core_default_route_table" "talos_rt" {
  manage_default_resource_id = oci_core_vcn.talos_vcn.default_route_table_id
  display_name               = "${var.cluster_name}-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.talos_ig.id
  }
}

resource "oci_core_default_security_list" "talos_sl" {
  manage_default_resource_id = oci_core_vcn.talos_vcn.default_security_list_id
  display_name               = "${var.cluster_name}-sl"

  # Permissive rules as per instructions (disabling firewall approach)
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
    stateless   = false
  }

  ingress_security_rules {
    source    = "0.0.0.0/0"
    protocol  = "all"
    stateless = false
  }
}
