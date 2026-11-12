terraform {
  required_version = "~> 1.13"

  backend "s3" {
    bucket       = "tofu-state"
    key          = "prod/infrastructure.tfstate"
    region       = "ap-hyderabad-1"
    profile      = "oci"
    use_lockfile = true

    # OCI Object Storage's S3 compatibility API, not AWS.
    endpoints = {
      s3 = "https://axshzxuad4ng.compat.objectstorage.ap-hyderabad-1.oci.customer-oci.com"
    }
    use_path_style              = true
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "9.13.0"
    }
  }
}

provider "oci" {
  config_file_profile = "DEFAULT"
  region              = "ap-hyderabad-1"
}
