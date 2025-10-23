resource "oci_core_instance" "controlplane" {
  count = var.control_plane_count

  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "talos-hyd-${count.index + 1}"
  shape               = var.instance_shape
  fault_domain        = "FAULT-DOMAIN-${count.index + 1}"

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_shape_config_memory_in_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.nodes.id
    display_name     = "primaryvnic"
    assign_public_ip = false
    hostname_label   = "talos-hyd-${count.index + 1}"
    private_ip       = "10.0.10.${count.index + 2}"
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.oracle_linux.images[0].id
    boot_volume_size_in_gbs = "200"
    boot_volume_vpus_per_gb = 120
  }

  # metadata = {
  #   user_data = base64encode(data.talos_machine_configuration.this.machine_configuration)
  # }

  agent_config {
    plugins_config {
      desired_state = "ENABLED"
      name          = "Bastion"
    }
  }

  lifecycle {
    ignore_changes = [metadata]
  }
}

data "oci_core_images" "oracle_linux" {
  compartment_id = var.compartment_ocid

  operating_system = "Oracle Linux"
  operating_system_version = "9"
  sort_by = "TIMECREATED"
}
