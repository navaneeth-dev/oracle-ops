{ config, ... }:
let
  pgPort = 5434;
  museumPort = 8180; # qBittorrent's WebUI has 8080
  # Only Postgres lives on this LV; the photos go to Garage's `ente` bucket.
  root = "/srv/ente";
  ph = config.sops.placeholder;
in
{
  sops.secrets = {
    ente-db-password.sopsFile = ./secrets.sops.yaml;
    ente-key-encryption.sopsFile = ./secrets.sops.yaml;
    ente-key-hash.sopsFile = ./secrets.sops.yaml;
    ente-jwt-secret.sopsFile = ./secrets.sops.yaml;
    ente-s3-key-id.sopsFile = ./secrets.sops.yaml;
    ente-s3-secret-key.sopsFile = ./secrets.sops.yaml;
  };

  sops.templates."ente-postgres.env".content = ''
    POSTGRES_PASSWORD=${ph.ente-db-password}
  '';

  sops.templates."museum.yaml" = {
    restartUnits = [ "podman-ente-museum.service" ];
    content = builtins.toJSON {
      log-file = "";
      http.port = museumPort;
      db = {
        host = "127.0.0.1";
        port = pgPort;
        name = "ente_db";
        user = "pguser";
        password = ph.ente-db-password;
      };
      # Clients upload straight to these presigned URLs, so museum signs
      # them for Garage's public endpoint. The bucket key name is fixed by
      # museum and has nothing to do with Backblaze.
      s3 = {
        are_local_buckets = false;
        use_path_style_urls = true;
        b2-eu-cen = {
          key = ph.ente-s3-key-id;
          secret = ph.ente-s3-secret-key;
          endpoint = "s3.fossindia.ovh";
          region = "garage";
          bucket = "ente";
        };
      };
      apps = {
        public-albums = "https://albums.fossindia.ovh";
        cast = "https://photos.fossindia.ovh";
        accounts = "https://photos.fossindia.ovh";
      };
      webauthn = {
        rpid = "photos.fossindia.ovh";
        rporigins = [ "https://photos.fossindia.ovh" ];
      };
      key = {
        encryption = ph.ente-key-encryption;
        hash = ph.ente-key-hash;
      };
      jwt.secret = ph.ente-jwt-secret;
      # Accounts are created by reopening this, not by self-signup.
      internal.disable-registration = true;
    };
  };

  virtualisation.oci-containers.containers = {
    ente-museum = {
      image = "ghcr.io/ente/server:latest@sha256:c59a19e16626a4fc3e9231c9a11c6fca0b342ba464c9b879635f549b977369fb";
      volumes = [ "${config.sops.templates."museum.yaml".path}:/museum.yaml:ro" ];
      dependsOn = [ "ente-postgres" ];
      extraOptions = [
        "--network=host"
        "--memory=512m"
        "--memory-swap=512m"
      ];
    };

    # Photos on 3000 and public albums on 3002; the image also serves its
    # other apps on 3001-3010, all closed by the firewall.
    ente-web = {
      image = "ghcr.io/ente/web:latest@sha256:f135d345510d9f85545960543961a7b6cd0b78d20e004704a2a0165b7692f3ef";
      environment.ENTE_API_ORIGIN = "https://ente.fossindia.ovh";
      extraOptions = [
        "--network=host"
        "--memory=128m"
        "--memory-swap=128m"
      ];
    };

    ente-postgres = {
      image = "docker.io/library/postgres:15@sha256:1aac5b49cefd627f02816141ca4ad012d6cc19460dfe02a9b5168a105be3fc53";
      environment = {
        PGPORT = toString pgPort;
        POSTGRES_USER = "pguser";
        POSTGRES_DB = "ente_db";
      };
      environmentFiles = [ config.sops.templates."ente-postgres.env".path ];
      cmd = [
        "postgres"
        "-c"
        "listen_addresses=127.0.0.1"
      ];
      volumes = [ "${root}/postgres:/var/lib/postgresql/data" ];
      extraOptions = [
        "--network=host"
        "--memory=512m"
        "--memory-swap=512m"
      ];
    };
  };

  systemd.services.podman-ente-postgres = {
    unitConfig.RequiresMountsFor = [ root ];
    # Created here rather than by tmpfiles, so it lands on the mounted LV.
    preStart = "mkdir -p ${root}/postgres";
  };

  services.traefik.dynamicConfigOptions.http = {
    routers = {
      ente-api = {
        rule = "Host(`ente.fossindia.ovh`)";
        entryPoints = [ "websecure" ];
        service = "ente-api";
      };
      ente-photos = {
        rule = "Host(`photos.fossindia.ovh`)";
        entryPoints = [ "websecure" ];
        service = "ente-photos";
      };
      ente-albums = {
        rule = "Host(`albums.fossindia.ovh`)";
        entryPoints = [ "websecure" ];
        service = "ente-albums";
      };
    };
    services = {
      ente-api.loadBalancer.servers = [ { url = "http://127.0.0.1:${toString museumPort}"; } ];
      ente-photos.loadBalancer.servers = [ { url = "http://127.0.0.1:3000"; } ];
      ente-albums.loadBalancer.servers = [ { url = "http://127.0.0.1:3002"; } ];
    };
  };
}
