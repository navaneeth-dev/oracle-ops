variable "ssh_public_key" {
}

variable "instance_shape" {
  default = "VM.Standard.A1.Flex"
}

variable "instance_ocpus" {
  default = 4
}

variable "instance_shape_config_memory_in_gbs" {
  description = "RAM for instances"
  default = 24
}

variable "control_plane_count" {
  default     = 1
  description = "Number of control plane nodes"
}

variable "cluster_name" {
  default = "ocihomelab"
}

// Oracle
variable "region" {
  default = "ap-hyderabad-1"
}

variable "compartment_ocid" {
}
