resource "oci_core_vcn" "talos" {
  compartment_id = local.compartment_id
  display_name   = "talos"
  cidr_blocks    = ["10.0.0.0/16"]

  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_core_internet_gateway" "talos" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.talos.id
  display_name   = "internetgateway20260101101120"
  enabled        = true
}

resource "oci_core_default_route_table" "talos" {
  manage_default_resource_id = oci_core_vcn.talos.default_route_table_id
  compartment_id             = local.compartment_id
  display_name               = "Default Route Table for talos"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.talos.id
  }
}

resource "oci_core_default_dhcp_options" "talos" {
  manage_default_resource_id = oci_core_vcn.talos.default_dhcp_options_id
  compartment_id             = local.compartment_id
  display_name               = "Default DHCP Options for talos"
  domain_name_type           = "CUSTOM_DOMAIN"

  options {
    type        = "DomainNameServer"
    server_type = "VcnLocalPlusInternet"
  }
}

resource "oci_core_default_security_list" "talos" {
  manage_default_resource_id = oci_core_vcn.talos.default_security_list_id
  compartment_id             = local.compartment_id
  display_name               = "Default Security List for talos"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    description = "Allow all Internal traffic"
    source      = "10.0.0.0/16"
    protocol    = "all"
  }

  # Envoy Gateway listeners on the gateway NLB.
  ingress_security_rules {
    description = "gateway allow from internet"
    source      = "0.0.0.0/0"
    protocol    = "6"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    description = "gateway allow from internet udp"
    source      = "0.0.0.0/0"
    protocol    = "17"
    udp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    description = "gateway allow from internet"
    source      = "0.0.0.0/0"
    protocol    = "6"
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    description = "gateway allow from internet"
    source      = "0.0.0.0/0"
    protocol    = "17"
    udp_options {
      min = 443
      max = 443
    }
  }

  # Envoy Gateway NodePorts behind the NLB, which preserves client source IPs.
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6"
    tcp_options {
      min = 32579
      max = 32579
    }
  }

  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "17"
    udp_options {
      min = 32579
      max = 32579
    }
  }

  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6"
    tcp_options {
      min = 31258
      max = 31258
    }
  }

  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "17"
    udp_options {
      min = 31258
      max = 31258
    }
  }
}

resource "oci_core_subnet" "kubernetes" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.talos.id
  display_name               = "kubernetes"
  cidr_block                 = "10.0.0.0/24"
  route_table_id             = oci_core_default_route_table.talos.id
  dhcp_options_id            = oci_core_default_dhcp_options.talos.id
  security_list_ids          = [oci_core_default_security_list.talos.id]
  prohibit_public_ip_on_vnic = false

  lifecycle {
    prevent_destroy = true
  }
}
