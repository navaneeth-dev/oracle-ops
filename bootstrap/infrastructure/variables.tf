variable "compartment_id" {
  type        = string
  description = "OCI Compartment OCID"
}

variable "talos_image_source_uri" {
  type        = string
  description = "OCI Object Storage URI for the talos-oracle-arm64.oci file"
  default = "factory.talos.dev/oracle-installer/376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
}

variable "instance_shape" {
  type    = string
  default = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  type    = number
  default = 2
}

variable "memory_in_gbs" {
  type    = number
  default = 12
}

variable "cluster_name" {
  type    = string
  default = "rizexor-oracle-dev"
}

variable "vcn_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.0.0/24"
}
