output "nlb_public_ip" {
  value = oci_network_load_balancer_network_load_balancer.talos_nlb.ip_addresses[0].ip_address
}

output "instance_public_ip" {
  value = oci_core_instance.talos_cp.public_ip
}
