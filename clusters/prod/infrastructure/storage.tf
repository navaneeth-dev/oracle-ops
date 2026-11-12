resource "oci_core_volume" "topolvm" {
  compartment_id      = local.compartment_id
  availability_domain = oci_core_instance.controlplane.availability_domain
  display_name        = "topolvm-storage"
  size_in_gbs         = "150"
  vpus_per_gb         = "120"

  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_core_volume_attachment" "topolvm" {
  attachment_type                     = "paravirtualized"
  display_name                        = "volumeattachment20260407183948"
  instance_id                         = oci_core_instance.controlplane.id
  volume_id                           = oci_core_volume.topolvm.id
  is_pv_encryption_in_transit_enabled = false
}
