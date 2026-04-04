resource "oci_network_load_balancer_network_load_balancer" "talos_nlb" {
  compartment_id = var.compartment_id
  display_name   = "${var.cluster_name}-nlb"
  subnet_id      = oci_core_subnet.talos_subnet.id
  
  is_private                     = false
  is_preserve_source_destination = false
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

# Backends (associated with the compute instance)
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
