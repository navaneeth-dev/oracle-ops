resource "oci_network_load_balancer_network_load_balancer" "gateway" {
  compartment_id                 = local.compartment_id
  display_name                   = "gateway"
  subnet_id                      = oci_core_subnet.kubernetes.id
  is_private                     = false
  is_preserve_source_destination = false
  is_symmetric_hash_enabled      = false
  nlb_ip_version                 = "IPV4"

  # Its public IP is ephemeral: replacing the NLB changes the address in DNS.
  lifecycle {
    prevent_destroy = true
  }
}

locals {
  # Envoy Gateway NodePorts behind each NLB listener.
  gateway_listeners = {
    http = {
      port      = 80
      node_port = 32579
    }
    https = {
      port      = 443
      node_port = 31258
    }
  }
}

resource "oci_network_load_balancer_backend_set" "gateway" {
  for_each = local.gateway_listeners

  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.gateway.id
  name                     = each.key
  policy                   = "FIVE_TUPLE"
  is_preserve_source       = true

  health_checker {
    protocol    = upper(each.key)
    port        = each.key == "https" ? each.value.node_port : 0
    url_path    = "/"
    return_code = 404
  }
}

resource "oci_network_load_balancer_listener" "gateway" {
  for_each = local.gateway_listeners

  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.gateway.id
  name                     = each.key
  default_backend_set_name = oci_network_load_balancer_backend_set.gateway[each.key].name
  port                     = each.value.port
  protocol                 = "TCP_AND_UDP"
  tcp_idle_timeout         = 120
  udp_idle_timeout         = 120
}

resource "oci_network_load_balancer_backend" "gateway" {
  for_each = local.gateway_listeners

  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.gateway.id
  backend_set_name         = oci_network_load_balancer_backend_set.gateway[each.key].name
  # Private IP OCID of the control plane instance replaced in April 2026. It no
  # longer exists, but the backends still route to its address, 10.0.0.11.
  # Pointing them at the current instance's private IP replaces both backends.
  target_id = "ocid1.privateip.oc1.ap-hyderabad-1.abuhsljrwvrektsw6nd4aurszkya5wsxwhlblr7xkbicete4edpz5fafsqla"
  port      = each.value.node_port
}
