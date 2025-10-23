resource "oci_core_instance" "controlplane" {
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "k3s-hyd-1"
  shape               = var.instance_shape
  fault_domain        = "FAULT-DOMAIN-1"

  shape_config {
    ocpus         = var.instance_ocpus
    memory_in_gbs = var.instance_shape_config_memory_in_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.nodes.id
    display_name     = "primaryvnic"
    assign_public_ip = true
    hostname_label   = "k3s-hyd-1"
    private_ip       = "10.0.10.2"
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = "50"
    boot_volume_vpus_per_gb = 120
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
  }
}

resource "oci_core_volume" "topolvm_volume" {
  availability_domain = data.oci_identity_availability_domain.ad.name
  compartment_id      = var.compartment_ocid
  display_name        = "topolvm-storage"
  size_in_gbs         = 150
  vpus_per_gb         = 120
}

resource "oci_core_volume_attachment" "topolvm_volume_attachment" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.controlplane.id
  volume_id       = oci_core_volume.topolvm_volume.id
  display_name    = "topolvm-attachment"
}


data "oci_core_images" "ubuntu" {
  compartment_id = var.compartment_ocid

  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04 Minimal aarch64"
  sort_by                  = "TIMECREATED"
}
