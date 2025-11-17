terraform {
  backend "oci" {
    bucket              = "terraform-state"
    namespace           = "axshzxuad4ng"
    config_file_profile = "AKASH"
  }

  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
    }

    oci = {
      source  = "oracle/oci"
      version = "7.26.1"
    }

    local = {
      source = "hashicorp/local"
      version = "2.6.0"
    }
  }
}

provider "talos" {}

provider "oci" {
  config_file_profile = "AKASH"
}
