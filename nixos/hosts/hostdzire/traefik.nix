# Traefik: public HTTPS entry point for services on this host. Certificates
# come from Let's Encrypt over a Cloudflare DNS-01 challenge, using the same
# API token as the cluster's cert-manager. sops-nix decrypts that Secret with
# this host's SSH key, which is a recipient in .sops.yaml.
# Routers are added by the services that need them; every router on
# websecure gets a certificate from the cloudflare resolver.
{ config, pkgs, ... }:
{
  sops.secrets.cloudflare-api-token = {
    sopsFile = ../../../k8s/infrastructure/configs/base/cert-manager/cloudflare-secret.yaml;
    # A Kubernetes Secret, so the value is base64-encoded.
    key = "data/api-token";
    owner = "traefik";
    restartUnits = [ "traefik.service" ];
  };

  services.traefik = {
    enable = true;
    staticConfigOptions = {
      entryPoints = {
        web = {
          address = ":80";
          http.redirections.entryPoint = {
            to = "websecure";
            scheme = "https";
          };
        };
        websecure = {
          address = ":443";
          http.tls.certResolver = "cloudflare";
        };
      };
      certificatesResolvers.cloudflare.acme = {
        email = "certs@rize.anonaddy.com";
        storage = "${config.services.traefik.dataDir}/acme.json";
        dnsChallenge.provider = "cloudflare";
      };
    };
  };

  systemd.services.traefik = {
    environment.CF_DNS_API_TOKEN_FILE = "/run/traefik/cf-api-token";
    serviceConfig.ExecStartPre = [
      (pkgs.writeShellScript "traefik-cf-token" ''
        umask 077
        ${pkgs.coreutils}/bin/base64 -d ${config.sops.secrets.cloudflare-api-token.path} \
          > /run/traefik/cf-api-token
      '')
    ];
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
