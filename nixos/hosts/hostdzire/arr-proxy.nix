# HTTP proxy for Sonarr and Radarr in the Oracle cluster, so their outbound
# HTTP leaves from this host's public IP (the same one qBittorrent uses).
# Reachable only over Tailscale, and only from oracle-prod: every pod reaches
# the tailnet as 100.92.137.3.
{ ... }:
{
  services.tinyproxy = {
    enable = true;
    settings = {
      # Listen on every address; the firewall below admits only tailscale0.
      # Binding to the tailnet IP would fail at boot before tailscaled is up.
      Listen = null;
      Port = 8888;
      Allow = [ "100.92.137.3" ];
      # Leave over IPv4 only, from the same address qBittorrent uses.
      Bind = "163.61.31.213";
      ConnectPort = [ 443 ]; # CONNECT only to HTTPS
      DisableViaHeader = true;
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8888 ];
}
