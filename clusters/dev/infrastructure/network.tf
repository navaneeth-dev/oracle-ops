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

resource "oci_core_subnet" "lb_subnet" {
  compartment_id = var.compartment_id
  vcn_id         = oci_core_vcn.talos_vcn.id
  cidr_block     = "10.0.1.0/24"
  display_name   = "Load Balancers Subnet"
  dns_label      = "lb"

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

resource "oci_network_load_balancer_network_load_balancer" "talos_nlb" {
  compartment_id = var.compartment_id
  display_name   = "Talos & Kubernetes Load Balancer"
  subnet_id      = oci_core_subnet.talos_subnet.id

  is_private                     = false
  is_preserve_source_destination = false
}

resource "oci_network_load_balancer_network_load_balancer" "gateway" {
  compartment_id = var.compartment_id
  display_name   = "Envoy Gateway Load Balancer"
  subnet_id      = oci_core_subnet.lb_subnet.id

  is_private                     = false
  is_preserve_source_destination = true
}

# Talos API Backend Set (Port 50000)
resource "oci_network_load_balancer_backend_set" "talos_api" {
  name                     = "talos-api"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.talos_nlb.id
  policy                   = "TWO_TUPLE"
  is_preserve_source       = false

  health_checker {
    port     = 50000
    protocol = "TCP"
  }
}

resource "oci_network_load_balancer_listener" "talos_api" {
  name                     = "talos-api"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.talos_nlb.id
  default_backend_set_name = oci_network_load_balancer_backend_set.talos_api.name
  port                     = 50000
  protocol                 = "TCP"
}

# Control Plane Backend Set (Port 6443)
resource "oci_network_load_balancer_backend_set" "controlplane" {
  name                     = "controlplane"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.talos_nlb.id
  policy                   = "TWO_TUPLE"
  is_preserve_source       = false

  health_checker {
    port        = 6443
    protocol    = "HTTPS"
    url_path    = "/readyz"
    return_code = 401
  }
}

resource "oci_network_load_balancer_listener" "controlplane" {
  name                     = "controlplane"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.talos_nlb.id
  default_backend_set_name = oci_network_load_balancer_backend_set.controlplane.name
  port                     = 6443
  protocol                 = "TCP"
}

resource "oci_network_load_balancer_backend" "talos_api" {
  backend_set_name         = oci_network_load_balancer_backend_set.talos_api.name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.talos_nlb.id
  port                     = 50000
  target_id                = oci_core_instance.talos_cp.id
}

resource "oci_network_load_balancer_backend" "controlplane" {
  backend_set_name         = oci_network_load_balancer_backend_set.controlplane.name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.talos_nlb.id
  port                     = 6443
  target_id                = oci_core_instance.talos_cp.id
}

# Gateway HTTP Backend Set (Port 80 -> NodePort 32579)
resource "oci_network_load_balancer_backend_set" "gateway_http" {
  name                     = "gateway-http"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.gateway.id
  policy                   = "TWO_TUPLE"
  is_preserve_source       = true

  health_checker {
    port     = 32579
    protocol = "TCP"
  }
}

resource "oci_network_load_balancer_listener" "gateway_http" {
  name                     = "gateway-http"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.gateway.id
  default_backend_set_name = oci_network_load_balancer_backend_set.gateway_http.name
  port                     = 80
  protocol                 = "TCP"
}

resource "oci_network_load_balancer_backend" "gateway_http" {
  backend_set_name         = oci_network_load_balancer_backend_set.gateway_http.name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.gateway.id
  port                     = 32579
  ip_address               = "10.0.0.11"
}

# Gateway HTTPS Backend Set (Port 443 -> NodePort 31258)
resource "oci_network_load_balancer_backend_set" "gateway_https" {
  name                     = "gateway-https"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.gateway.id
  policy                   = "TWO_TUPLE"
  is_preserve_source       = true

  health_checker {
    port     = 31258
    protocol = "TCP"
  }
}

resource "oci_network_load_balancer_listener" "gateway_https" {
  name                     = "gateway-https"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.gateway.id
  default_backend_set_name = oci_network_load_balancer_backend_set.gateway_https.name
  port                     = 443
  protocol                 = "TCP"
}

resource "oci_network_load_balancer_backend" "gateway_https" {
  backend_set_name         = oci_network_load_balancer_backend_set.gateway_https.name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.gateway.id
  port                     = 31258
  ip_address               = "10.0.0.11"
}
