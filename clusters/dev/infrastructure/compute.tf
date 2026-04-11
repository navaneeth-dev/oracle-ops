resource "oci_core_instance" "talos_cp" {
  lifecycle {
    prevent_destroy = true
  }

  compartment_id      = var.compartment_id
  availability_domain = data.oci_identity_availability_domain.ads.name
  display_name        = "controlplane-rizexor-dev1"
  shape               = var.instance_shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  source_details {
    source_type = "image"
    source_id   = oci_core_image.talos.id
    boot_volume_vpus_per_gb = "120"
    is_preserve_boot_volume_enabled = false
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.talos_subnet.id
    display_name     = "primaryvnic"
    assign_public_ip = true
    private_ip       = "10.0.0.11"
    hostname_label   = "controlplane-rizexor-dev1"
  }

  launch_options {
    network_type = "PARAVIRTUALIZED"
  }
}

data "oci_identity_availability_domain" "ads" {
  compartment_id = var.compartment_id

  ad_number = 1
}
