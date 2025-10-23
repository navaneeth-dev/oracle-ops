resource "oci_network_load_balancer_listener" "http" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.traefik_nlb.id
  name                     = "${var.cluster_name}-http-listener"
  default_backend_set_name = oci_network_load_balancer_backend_set.http_traefik_nlb.name
  port                     = 80
  protocol                 = "TCP"
}

resource "oci_network_load_balancer_listener" "https" {
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.traefik_nlb.id
  name                     = "${var.cluster_name}-https-listener"
  default_backend_set_name = oci_network_load_balancer_backend_set.https_traefik_nlb.name
  port                     = 443
  protocol                 = "TCP"
}
