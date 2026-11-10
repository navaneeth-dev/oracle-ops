# Garage: single-node S3 at https://s3.fossindia.ovh, behind Traefik. Data and
# metadata live on their own logical volume (/srv/garage, see disko.nix) so a
# full bucket cannot fill /srv and the NFS media. The cluster layout, buckets
# and keys are runtime state managed with the `garage` CLI; see
# nixos/README.md.
{ config, pkgs, ... }:
{
  sops.secrets.garage-rpc-secret = {
    sopsFile = ./secrets.sops.yaml;
    owner = "garage";
    restartUnits = [ "garage.service" ];
  };

  services.garage = {
    enable = true;
    package = pkgs.garage_2;
    settings = {
      metadata_dir = "/srv/garage/meta";
      data_dir = "/srv/garage/data";
      replication_factor = 1;
      # Photos and videos are already compressed.
      compression_level = "none";
      # One copy and no other node to repair from.
      data_fsync = true;
      metadata_auto_snapshot_interval = "6h";
      rpc_bind_addr = "127.0.0.1:3901";
      rpc_public_addr = "127.0.0.1:3901";
      rpc_secret_file = config.sops.secrets.garage-rpc-secret.path;
      s3_api = {
        s3_region = "garage";
        api_bind_addr = "127.0.0.1:3900";
      };
    };
  };

  # A fixed user instead of the module's DynamicUser, so the files on the
  # volume keep a stable owner.
  users.users.garage = {
    isSystemUser = true;
    group = "garage";
  };
  users.groups.garage = { };
  systemd.services.garage = {
    unitConfig.RequiresMountsFor = [ "/srv/garage" ];
    serviceConfig = {
      DynamicUser = false;
      User = "garage";
      Group = "garage";
    };
  };
  systemd.tmpfiles.settings."10-garage" = {
    "/srv/garage/meta".d = {
      user = "garage";
      group = "garage";
      mode = "0700";
    };
    "/srv/garage/data".d = {
      user = "garage";
      group = "garage";
      mode = "0700";
    };
  };

  services.traefik.dynamicConfigOptions.http = {
    routers.garage = {
      rule = "Host(`s3.fossindia.ovh`)";
      entryPoints = [ "websecure" ];
      service = "garage";
    };
    services.garage.loadBalancer.servers = [ { url = "http://127.0.0.1:3900"; } ];
  };
}
