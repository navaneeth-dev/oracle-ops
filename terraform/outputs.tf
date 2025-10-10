output "kubeconfig" {
  value     = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "bastion_session_talos" {
  value       = "${oci_bastion_session.talos_session.bastion_user_name}@host.bastion.${var.region}.oci.oraclecloud.com"
  description = "Bastion Talos SSH host"
}

output "bastion_session_k8s_api" {
  value       = "${oci_bastion_session.k8s_api_session.bastion_user_name}@host.bastion.${var.region}.oci.oraclecloud.com"
  description = "Bastion K8S API SSH host"
}
