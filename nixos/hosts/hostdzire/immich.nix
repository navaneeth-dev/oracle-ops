{ config, pkgs, ... }:
let
  pgPort = "5433";
  redisPort = "6380";
  # Postgres, uploads and thumbnails all live on this LV, so removing Immich
  # is `lvremove vg0/immich` and growing it is `lvextend -r`.
  root = "/srv/immich";
in
{
  sops.secrets.immich-db-password.sopsFile = ./secrets.sops.yaml;
  sops.templates."immich.env".content = ''
    DB_PASSWORD=${config.sops.placeholder.immich-db-password}
    POSTGRES_PASSWORD=${config.sops.placeholder.immich-db-password}
  '';

  # Host networking like the other containers here; every port binds to
  # loopback and only Traefik is public. No machine-learning container:
  # faces, smart search and OCR stay off.
  virtualisation.oci-containers.containers = {
    immich-server = {
      image = "ghcr.io/immich-app/immich-server:v3.4.1@sha256:7c489add298fc2f92cda4c777de6462aa206877e04087b815f62c7664af0b53b";
      environment = {
        TZ = "Asia/Kolkata";
        IMMICH_HOST = "127.0.0.1";
        IMMICH_PORT = "2283";
        IMMICH_TRUSTED_PROXIES = "127.0.0.1";
        DB_HOSTNAME = "127.0.0.1";
        DB_PORT = pgPort;
        DB_USERNAME = "postgres";
        DB_DATABASE_NAME = "immich";
        REDIS_HOSTNAME = "127.0.0.1";
        REDIS_PORT = redisPort;
      };
      environmentFiles = [ config.sops.templates."immich.env".path ];
      volumes = [ "${root}/library:/data" ];
      dependsOn = [
        "immich-postgres"
        "immich-redis"
      ];
      extraOptions = [
        "--network=host"
        # About 1.2 GiB idle with its API and microservices workers.
        "--memory=2g"
        "--memory-swap=2g"
      ];
    };

    immich-postgres = {
      image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0@sha256:bcf63357191b76a916ae5eb93464d65c07511da41e3bf7a8416db519b40b1c23";
      environment = {
        PGPORT = pgPort;
        POSTGRES_USER = "postgres";
        POSTGRES_DB = "immich";
        POSTGRES_INITDB_ARGS = "--data-checksums";
      };
      environmentFiles = [ config.sops.templates."immich.env".path ];
      cmd = [
        "postgres"
        "-c"
        "config_file=/etc/postgresql/postgresql.conf"
        "-c"
        "listen_addresses=127.0.0.1"
      ];
      volumes = [ "${root}/postgres:/var/lib/postgresql/data" ];
      extraOptions = [
        "--network=host"
        "--shm-size=128m"
        # The image's postgresql.conf sets shared_buffers = 512MB.
        "--memory=1g"
        "--memory-swap=1g"
      ];
    };

    immich-redis = {
      image = "docker.io/valkey/valkey:9@sha256:418652cfb58ef879d4978c33553735d7147016032d5aefaa14c828e611eb9dfd";
      cmd = [
        "valkey-server"
        "--bind"
        "127.0.0.1"
        "--port"
        redisPort
        "--save"
        ""
      ];
      extraOptions = [
        "--network=host"
        "--memory=128m"
        "--memory-swap=128m"
      ];
    };
  };

  systemd.services = {
    # Created here rather than by tmpfiles, so they land on the mounted LV.
    podman-immich-server = {
      unitConfig.RequiresMountsFor = [ root ];
      preStart = "mkdir -p ${root}/library";
    };
    podman-immich-postgres = {
      unitConfig.RequiresMountsFor = [ root ];
      preStart = "mkdir -p ${root}/postgres";
    };

    # Immich has no setting outside its database for this, and its config
    # file would lock every other admin setting. Seed the database default
    # once; the admin UI can still change it later.
    immich-disable-ml = {
      wantedBy = [ "multi-user.target" ];
      after = [ "podman-immich-server.service" ];
      wants = [ "podman-immich-server.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "10min";
      };
      path = [ pkgs.podman ];
      script = ''
        psql() { podman exec immich-postgres psql -U postgres -d immich -tAc "$1"; }
        until [ "$(psql "SELECT to_regclass('system_metadata') IS NOT NULL" 2>/dev/null)" = t ]; do
          sleep 2
        done
        if [ "$(psql "SELECT count(*) FROM system_metadata WHERE key = 'system-config'")" = 0 ]; then
          psql "INSERT INTO system_metadata (key, value) VALUES ('system-config', '{\"machineLearning\": {\"enabled\": false}}')"
          systemctl restart --no-block podman-immich-server.service
        fi
      '';
    };
  };

  services.traefik.dynamicConfigOptions.http = {
    routers.immich = {
      rule = "Host(`immich.fossindia.ovh`)";
      entryPoints = [ "websecure" ];
      service = "immich";
    };
    services.immich.loadBalancer.servers = [ { url = "http://127.0.0.1:2283"; } ];
  };
}
