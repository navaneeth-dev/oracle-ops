# Tdarr server + one node: adds a boosted stereo track to every movie and TV
# file in place (see docs/operations/tdarr/README.md for the flow).
{ lib, pkgs, ... }:
let
  env = {
    TZ = "Asia/Kolkata";
    PUID = "1000"; # rize, the owner of the media
    PGID = "1000";
    UMASK_SET = "022";
    ffmpegVersion = "7";
    inContainer = "true";
  };
  # One mount for media and the transcode cache, so replacing a file is a
  # rename instead of a full copy.
  volumes = [
    "/srv/tdarr/configs:/app/configs"
    "/srv/tdarr/logs:/app/logs"
    "/srv:/srv"
  ];
in
{
  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers = {
    # Host networking: the UI (8265) is reachable only through the firewall's
    # tailscale0 rule, and the node reaches the server (8266) on loopback.
    # Image digests pin the linux/amd64 manifests.
    tdarr = {
      image = "ghcr.io/haveagitgat/tdarr:3.04.00@sha256:0ea9217f69f40e49977dbcbc0319224e625c90d808d39bf075483fe45e9612f1";
      environment = env // {
        serverIP = "0.0.0.0";
        serverPort = "8266";
        webUIPort = "8265";
        internalNode = "false";
        auth = "false";
      };
      volumes = volumes ++ [ "/srv/tdarr/server:/app/server" ];
      extraOptions = [ "--network=host" "--memory=768m" "--memory-swap=768m" ];
    };
    tdarr-node = {
      image = "ghcr.io/haveagitgat/tdarr_node:3.04.00@sha256:05bbccf0f20c8b79e21424b553149a85f5bac588a9392986feaa440517bf491f";
      dependsOn = [ "tdarr" ];
      environment = env // {
        nodeName = "hostdzire";
        serverURL = "http://127.0.0.1:8266";
        serverIP = "127.0.0.1";
        serverPort = "8266";
        transcodecpuWorkers = "1";
        transcodegpuWorkers = "0";
        healthcheckcpuWorkers = "0";
        healthcheckgpuWorkers = "0";
      };
      inherit volumes;
      # Leave CPU and RAM for nfsd, tailscaled and the page cache.
      extraOptions = [ "--network=host" "--memory=1g" "--memory-swap=1g" "--cpus=1.5" ];
    };
  };

  systemd.tmpfiles.settings."20-tdarr" = lib.genAttrs [
    "/srv/tdarr"
    "/srv/tdarr/server"
    "/srv/tdarr/configs"
    "/srv/tdarr/logs"
    "/srv/tdarr/cache"
  ] (_: { d = { user = "rize"; group = "rize"; mode = "0755"; }; });

  # Upsert the flow and the Movies/TV libraries from this repo.
  systemd.services.tdarr-configure = {
    description = "Configure the Tdarr flow and libraries";
    after = [ "podman-tdarr.service" ];
    requires = [ "podman-tdarr.service" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ ./tdarr ];
    path = [ pkgs.curl pkgs.python3 ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "10min";
    };
    script = ''
      until curl -fsS http://127.0.0.1:8265/api/v2/status >/dev/null; do sleep 5; done
      python3 ${./tdarr}/configure.py http://127.0.0.1:8265
    '';
  };
}
