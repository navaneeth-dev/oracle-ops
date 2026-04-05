variable "compartment_id" {
  type        = string
  description = "OCI Compartment OCID"
}

variable "bucket_name" {
  type        = string
  description = "OCI Object Storage Bucket Name"
  default     = "talos-images"
}

variable "talos_version" {
  type        = string
  description = "Talos Version (used for naming)"
  default     = "1.12.6"
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
