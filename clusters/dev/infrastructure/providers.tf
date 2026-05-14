terraform {
  backend "oci" {
    bucket            = "terraform-state"
    namespace         = "axshzxuad4ng"

    key               = "homelab-oracle-dev/terraform.tfstate"
    config_file_profile = "DEFAULT"
  }

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "8.14.0"
    }
  }
}

provider "oci" {
  config_file_profile = "MUMBAI"
}
