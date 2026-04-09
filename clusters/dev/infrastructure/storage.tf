data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.compartment_id
}

resource "oci_objectstorage_bucket" "talos_images" {
  compartment_id = var.compartment_id
  name           = var.bucket_name
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  storage_tier   = "Standard"
}

resource "oci_objectstorage_object" "talos_oci" {
  bucket    = oci_objectstorage_bucket.talos_images.name
  namespace = data.oci_objectstorage_namespace.ns.namespace
  object    = "oracle-arm64.oci"
  source    = "${path.module}/files/oracle-arm64.oci"
}

resource "oci_core_image" "talos" {
  compartment_id = var.compartment_id
  display_name   = "Talos Linux"

  image_source_details {
    source_type = "objectStorageTuple"
    bucket_name = var.bucket_name
    namespace_name = data.oci_objectstorage_namespace.ns.namespace
    object_name = oci_objectstorage_object.talos_oci.object

    #Optional
    # operating_system = var.image_image_source_details_operating_system
    # operating_system_version = var.image_image_source_details_operating_system_version
    # source_image_type = var.source_image_type
  }
}

resource "oci_core_volume" "topolvm_data" {
  compartment_id = var.compartment_id

  availability_domain = data.oci_identity_availability_domain.ads.name
  display_name = "Topolvm Data"
  size_in_gbs = 150
  vpus_per_gb = "120"

  lifecycle {
    ignore_changes = all
    prevent_destroy = true
  }
}

resource "oci_core_volume_attachment" "topolvm_data" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.talos_cp.id
  volume_id       = oci_core_volume.topolvm_data.id
}
