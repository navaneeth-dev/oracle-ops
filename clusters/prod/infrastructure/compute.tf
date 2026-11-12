resource "oci_core_image" "talos" {
  compartment_id = local.compartment_id
  display_name   = "Talos v1.12.0"
  launch_mode    = "PARAVIRTUALIZED"
}

resource "oci_core_instance" "controlplane" {
  compartment_id      = local.compartment_id
  availability_domain = "Imrj:AP-HYDERABAD-1-AD-1"
  fault_domain        = "FAULT-DOMAIN-2"
  display_name        = "controlplane-rizexor-prod1"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 4
    memory_in_gbs = 24
  }

  source_details {
    source_type                     = "image"
    source_id                       = oci_core_image.talos.id
    boot_volume_size_in_gbs         = "47"
    boot_volume_vpus_per_gb         = "120"
    is_preserve_boot_volume_enabled = false
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.kubernetes.id
    display_name     = "controlplane-rizexor-prod1"
    assign_public_ip = "true"
    private_ip       = "10.0.0.11"
  }

  launch_options {
    boot_volume_type                    = "PARAVIRTUALIZED"
    firmware                            = "UEFI_64"
    network_type                        = "PARAVIRTUALIZED"
    remote_data_volume_type             = "PARAVIRTUALIZED"
    is_consistent_volume_naming_enabled = true
    is_pv_encryption_in_transit_enabled = true
  }

  availability_config {
    is_live_migration_preferred = false
    recovery_action             = "RESTORE_INSTANCE"
  }

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false

    plugins_config {
      desired_state = "DISABLED"
      name          = "WebLogic Management Service"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Vulnerability Scanning"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Oracle Java Management Service"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "OS Management Hub Agent"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Management Agent"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Fleet Application Management Service"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Custom Logs Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute RDMA GPU Monitoring"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Run Command"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Auto-Configuration"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Authentication"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Cloud Guard Workload Protection"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Block Volume Management"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Bastion"
    }
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = false
  }

  lifecycle {
    prevent_destroy = true
  }
}
