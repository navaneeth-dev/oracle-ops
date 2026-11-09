# qBittorrent next to its storage, so downloads write to local ext4 instead
# of NFS (see docs/experiments/qbittorrent-on-nfs.md). Peers reach this host's
# public IP directly; the WebUI and API are reachable only over Tailscale.
{ lib, ... }:
{
  virtualisation.oci-containers.containers.qbittorrent = {
    # The digest pins the linux/amd64 manifest.
    image = "ghcr.io/home-operations/qbittorrent:5.2.4@sha256:e2152a959659db421198b75abf2fd1b89086ca3ac8c1eedd6bcbe5d99617a6f5";
    user = "1000:1000"; # rize, the owner of the media
    environment = {
      TZ = "Asia/Kolkata";
      QBT_WEBUI_PORT = "8080";
      QBT_TORRENTING_PORT = "41047";
    };
    volumes = [
      "/srv/qbittorrent/config:/config"
      # Same path as the Oracle pods' NFS mount, so Sonarr and Radarr see the
      # paths qBittorrent reports without remote path mappings.
      "/srv/nfs-data/oracle:/hostdzire"
    ];
    extraOptions = [ "--network=host" "--memory=2g" "--memory-swap=2g" ];
  };

  systemd.tmpfiles.settings."20-qbittorrent" = lib.genAttrs [
    "/srv/qbittorrent"
    "/srv/qbittorrent/config"
  ] (_: { d = { user = "rize"; group = "rize"; mode = "0755"; }; });

  networking.firewall = {
    allowedTCPPorts = [ 41047 ];
    allowedUDPPorts = [ 41047 ];
    interfaces.tailscale0.allowedTCPPorts = [ 8080 ]; # WebUI and API
  };
}
