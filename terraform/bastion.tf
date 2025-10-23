resource "oci_bastion_bastion" "kubernetes" {
  bastion_type     = "STANDARD"
  compartment_id   = var.compartment_ocid
  target_subnet_id = oci_core_subnet.nodes.id
  name             = "Kubernetes"

  client_cidr_block_allow_list = ["0.0.0.0/0"]
}

resource "oci_bastion_session" "ssh" {
  count = var.control_plane_count

  bastion_id             = oci_bastion_bastion.kubernetes.id
  display_name           = "Node${count.index}-SSH"
  session_ttl_in_seconds = 60 * 60 * 3 # 3 hours

  key_details {
    public_key_content = var.ssh_public_key
  }

  target_resource_details {
    session_type = "MANAGED_SSH"

    target_resource_operating_system_user_name = "opc"
    target_resource_id                         = oci_core_instance.controlplane[0].id
    target_resource_private_ip_address         = oci_core_instance.controlplane[0].private_ip
    target_resource_port                       = 22
  }
}

resource "oci_bastion_session" "kubernetes_api_server" {
  bastion_id             = oci_bastion_bastion.kubernetes.id
  display_name           = "Kubernetes-API-Server"
  session_ttl_in_seconds = 60 * 60 * 3

  key_details {
    public_key_content = var.ssh_public_key
  }
  target_resource_details {
    session_type                       = "PORT_FORWARDING"
    target_resource_private_ip_address = oci_network_load_balancer_network_load_balancer.talos.assigned_private_ipv4
    target_resource_port               = 6443
  }
}
