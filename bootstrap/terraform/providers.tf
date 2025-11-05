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
      version = "7.25.0"
    }

    local = {
      source = "hashicorp/local"
      version = "2.5.3"
    }
  }
}

provider "talos" {}

provider "oci" {
  config_file_profile = "AKASH"
}
