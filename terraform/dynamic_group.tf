resource "oci_identity_dynamic_group" "all_vms" {
    compartment_id = var.compartment_ocid
    description = "All VMs in compartment"
    matching_rule = "Any {instance.compartment.id = '${var.compartment_ocid}'}"
    name = "all-vms"
}

resource "oci_identity_policy" "csi_policy" {
    compartment_id = var.compartment_ocid
    description = "Grant permission to create Block Storage via CSI Kubernetes"
    name = "allow-csi-block-storage"
    statements = [
      "allow dynamic-group ${oci_identity_dynamic_group.all_vms.name} to use instance-family in compartment id ${var.compartment_ocid}",
      "allow dynamic-group ${oci_identity_dynamic_group.all_vms.name} to use virtual-network-family in compartment id ${var.compartment_ocid}",
      "allow dynamic-group ${oci_identity_dynamic_group.all_vms.name} to manage volume-family in compartment id ${var.compartment_ocid}"
    ]
}
