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
  display_name   = "talos-${var.talos_version}"

  image_source_details {
    source_type = "objectStorageUri"
    # Construct the URI: https://objectstorage.<region>.oraclecloud.com/n/<namespace>/b/<bucket>/o/<object>
    source_uri  = "https://objectstorage.${var.region}.oraclecloud.com/n/${data.oci_objectstorage_namespace.ns.namespace}/b/${oci_objectstorage_bucket.talos_images.name}/o/${oci_objectstorage_object.talos_oci.object}"
  }

  operating_system         = "Talos"
  operating_system_version = var.talos_version
}
