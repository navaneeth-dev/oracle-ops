resource "oci_network_load_balancer_network_load_balancer" "talos" {
  compartment_id = var.compartment_ocid
  display_name   = "talos"
  subnet_id      = oci_core_subnet.loadbalancers.id
  is_private = true # Make the load balancer private

  assigned_private_ipv4 = "10.0.60.200"
}

resource "oci_network_load_balancer_network_load_balancer" "traefik_nlb" {
  compartment_id = var.compartment_ocid
  display_name   = "traefik_ingress_nlb"
  subnet_id      = oci_core_subnet.public_lbs.id
  is_private = false # Make the load balancer private
  nlb_ip_version = "IPV4_AND_IPV6"

  assigned_ipv6 = cidrhost(oci_core_subnet.public_lbs.ipv6cidr_block, 200)
  # subnet_ipv6cidr = oci_core_subnet.public_lbs.ipv6cidr_block
}

// nlb -> HTTPs load balancer
resource "oci_network_load_balancer_backend_set" "https_traefik_nlb" {
  name                     = "${var.cluster_name}-traefik_https_nlb"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.traefik_nlb.id
  policy                   = "FIVE_TUPLE"

  health_checker {
    port               = 31258
    interval_in_millis = 10000
    protocol           = "HTTPS"
    return_code        = 404
    url_path           = "/"
  }
}

// nlb -> HTTP load balancer
resource "oci_network_load_balancer_backend_set" "http_traefik_nlb" {
  name                     = "${var.cluster_name}-traefik_http_nlb"
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.traefik_nlb.id
  policy                   = "FIVE_TUPLE"

  health_checker {
    port               = 32579
    interval_in_millis = 10000
    protocol           = "HTTP"
    return_code        = 404
    url_path           = "/"
  }
}

resource "oci_network_load_balancer_backend" "http" {
  count = var.control_plane_count

  backend_set_name         = oci_network_load_balancer_backend_set.http_traefik_nlb.name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.traefik_nlb.id
  port                     = 32579
  ip_address               = oci_core_instance.controlplane.private_ip
}

resource "oci_network_load_balancer_backend" "https" {
  count = var.control_plane_count

  backend_set_name         = oci_network_load_balancer_backend_set.https_traefik_nlb.name
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.traefik_nlb.id
  port                     = 31258
  ip_address               = oci_core_instance.controlplane.private_ip
}
