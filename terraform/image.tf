resource "oci_core_image" "talos_image" {
  compartment_id = var.compartment_ocid

  display_name = "Talos Linux"

  image_source_details {
    source_type = "objectStorageTuple"
    bucket_name = "isos"
    namespace_name = "axshzxuad4ng"
    object_name = "oracle-arm64.oci"
  }
}