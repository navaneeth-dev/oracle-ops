# End-to-end test of the planned hostdzire6tb object store: Garage (single
# node) behind Traefik with TLS, plus garage-webui, and a client VM that does
# what Ente's apps do: upload and download through presigned URLs, including
# multipart uploads for videos, with browser CORS preflights.
#
#   nix build .#checks.x86_64-linux.garage -L
#   nix run .#checks.x86_64-linux.garage.driverInteractive   # poke around
{ pkgs, lib, ... }:
let
  domain = "acme.test";
  s3Host = "s3.${domain}";
  # Test-only certificate for *.acme.test (includes s3.acme.test), shipped
  # with nixpkgs' own Ente test.
  certDir = "${pkgs.path}/nixos/tests/ente";

  # Test-only credentials.
  rpcSecret = "457ca1da5e96a037e0def4ac8520a84ddd94ce1e21d9431a7c38395655a5d226";
  adminToken = "test-admin-token";
  enteKeyId = "GK0123456789abcdef01234567";
  enteSecret = "1111111111111111111111111111111111111111111111111111111111111111";
  ownerKeyId = "GKfedcba9876543210fedcba98";
  ownerSecret = "2222222222222222222222222222222222222222222222222222222222222222";
  # admin / test-password
  webuiAuth = "admin:$2y$10$b.blcacHpW5WOgsrEGp2CeW9Ai05groc27beBTsxtO9ZnVrXuTfJq";

  awsEnv = keyId: secret: ''
    export AWS_ACCESS_KEY_ID=${keyId} AWS_SECRET_ACCESS_KEY=${secret}
    export AWS_DEFAULT_REGION=garage AWS_ENDPOINT_URL=https://${s3Host}
    export AWS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
  '';
in
{
  name = "garage-s3";

  nodes.s3 =
    { pkgs, ... }:
    {
      services.garage = {
        enable = true;
        package = pkgs.garage_2;
        settings = {
          replication_factor = 1;
          # Photos and videos are already compressed.
          compression_level = "none";
          # One copy and no other node to repair from.
          data_fsync = true;
          metadata_auto_snapshot_interval = "6h";
          rpc_bind_addr = "127.0.0.1:3901";
          rpc_public_addr = "127.0.0.1:3901";
          rpc_secret = rpcSecret;
          s3_api = {
            s3_region = "garage";
            api_bind_addr = "127.0.0.1:3900";
          };
          admin = {
            api_bind_addr = "127.0.0.1:3903";
            admin_token = adminToken;
          };
        };
      };

      systemd.services.garage-webui = {
        after = [ "garage.service" ];
        wantedBy = [ "multi-user.target" ];
        environment = {
          HOST = "127.0.0.1";
          PORT = "3909";
          API_BASE_URL = "http://127.0.0.1:3903";
          API_ADMIN_KEY = adminToken;
          S3_ENDPOINT_URL = "http://127.0.0.1:3900";
          S3_REGION = "garage";
          AUTH_USER_PASS = webuiAuth;
        };
        serviceConfig = {
          ExecStart = lib.getExe pkgs.garage-webui;
          DynamicUser = true;
        };
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
            websecure.address = ":443";
          };
        };
        dynamicConfigOptions = {
          tls.certificates = [
            {
              certFile = "${certDir}/${domain}.cert.pem";
              keyFile = "${certDir}/${domain}.key.pem";
            }
          ];
          http = {
            routers.garage-s3 = {
              rule = "Host(`${s3Host}`)";
              entryPoints = [ "websecure" ];
              service = "garage-s3";
              tls = { };
            };
            services.garage-s3.loadBalancer.servers = [ { url = "http://127.0.0.1:3900"; } ];
          };
        };
      };

      networking.firewall.allowedTCPPorts = [
        80
        443
      ];
      environment.systemPackages = [ pkgs.jq ];
      # Garage refuses to start with less than 1 GiB free.
      virtualisation.diskSize = 2 * 1024;
    };

  nodes.client =
    { nodes, pkgs, ... }:
    {
      security.pki.certificateFiles = [ "${certDir}/ca.cert.pem" ];
      networking.extraHosts = "${nodes.s3.networking.primaryIPAddress} ${s3Host}";
      environment.systemPackages = [
        pkgs.awscli2
        pkgs.jq
        (pkgs.writeShellScriptBin "s3helper" ''
          ${awsEnv enteKeyId enteSecret}
          exec ${pkgs.python3.withPackages (p: [ p.boto3 ])}/bin/python3 ${./s3helper.py} "$@"
        '')
        (pkgs.writeShellScriptBin "aws-ente" ''
          ${awsEnv enteKeyId enteSecret}
          exec aws "$@"
        '')
        (pkgs.writeShellScriptBin "aws-owner" ''
          ${awsEnv ownerKeyId ownerSecret}
          exec aws "$@"
        '')
      ];
    };

  testScript = ''
    import json

    S3 = "https://${s3Host}"

    def put_presigned(key, path):
        p = json.loads(client.succeed(f"s3helper presign-put {key} {path}"))
        client.succeed(f"curl -sSf -X PUT -H 'Content-MD5: {p['md5']}' --upload-file {path} '{p['url']}'")

    def get_presigned_sha(key):
        url = client.succeed(f"s3helper presign-get {key}").strip()
        return client.succeed(f"curl -sSf '{url}' | sha256sum").split()[0]

    def sha(path):
        return client.succeed(f"sha256sum {path}").split()[0]

    start_all()

    with subtest("Garage starts as a one-node cluster"):
        s3.wait_for_unit("garage.service")
        s3.wait_for_open_port(3900)
        node_id = s3.succeed("garage node id -q").split("@")[0]
        s3.succeed(f"garage layout assign -z dc1 -c 1G {node_id}")
        s3.succeed("garage layout apply --version 1")
        s3.succeed("garage key import --yes -n ente ${enteKeyId} ${enteSecret}")
        s3.succeed("garage key import --yes -n owner ${ownerKeyId} ${ownerSecret}")
        s3.succeed("garage bucket create ente")
        s3.succeed("garage bucket allow --read --write ente --key ente")
        s3.succeed("garage bucket allow --read --write --owner ente --key owner")

    with subtest("Only Traefik is reachable from outside"):
        s3.wait_for_unit("traefik.service")
        s3.wait_for_open_port(443)
        client.wait_for_unit("multi-user.target")
        client.wait_until_succeeds(f"curl -sS -o /dev/null {S3}/", timeout=60)
        for port in [3900, 3901, 3903, 3909]:
            client.fail(f"curl -sS -m 5 http://${s3Host}:{port}/")
        out = client.succeed("curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' http://${s3Host}/ente")
        assert out.startswith("30") and out.endswith("https://${s3Host}/ente"), out

    with subtest("Signed requests work through the proxy"):
        client.succeed("aws-ente s3 ls s3://ente")
        # Anonymous requests are refused; the bucket is not public.
        client.fail(f"curl -sSf -o /dev/null {S3}/ente/")

    with subtest("Only the owner key may set CORS"):
        cors = json.dumps({"CORSRules": [{
            "AllowedHeaders": ["*"],
            "AllowedMethods": ["GET", "PUT", "POST", "DELETE"],
            "AllowedOrigins": ["*"],
            "ExposeHeaders": ["ETag"],
        }]})
        client.succeed(f"echo '{cors}' > /tmp/cors.json")
        client.fail("aws-ente s3api put-bucket-cors --bucket ente --cors-configuration file:///tmp/cors.json")
        client.succeed("aws-owner s3api put-bucket-cors --bucket ente --cors-configuration file:///tmp/cors.json")

    with subtest("Browser CORS preflight passes, including Origin: null"):
        for origin in ["https://photos.${domain}", "null"]:
            hdrs = client.succeed(
                f"curl -sSf -o /dev/null -D - -X OPTIONS {S3}/ente/some/object "
                f"-H 'Origin: {origin}' -H 'Access-Control-Request-Method: PUT' "
                "-H 'Access-Control-Request-Headers: content-md5,content-type'"
            ).lower()
            assert "access-control-allow-origin: *" in hdrs, hdrs
            assert "put" in hdrs.split("access-control-allow-methods:")[1].splitlines()[0], hdrs

    with subtest("Photo: presigned PUT with Content-MD5, HEAD, presigned GET"):
        client.succeed("head -c 3M /dev/urandom > /tmp/photo.jpg")
        put_presigned("user1/photo.jpg", "/tmp/photo.jpg")
        head = json.loads(client.succeed("s3helper head user1/photo.jpg"))
        assert head["size"] == 3 * 1024 * 1024, head
        assert get_presigned_sha("user1/photo.jpg") == sha("/tmp/photo.jpg")
        # A browser GET sees the ETag, which Ente's web app reads.
        url = client.succeed("s3helper presign-get user1/photo.jpg").strip()
        hdrs = client.succeed(f"curl -sSf -o /dev/null -D - -H 'Origin: https://photos.${domain}' '{url}'").lower()
        assert "access-control-expose-headers: etag" in hdrs, hdrs

    with subtest("Bad uploads are rejected"):
        client.succeed("head -c 1K /dev/urandom > /tmp/small.bin")
        # A Content-MD5 that does not match the body.
        wrong = "1B2M2Y8AsgTpgAmY7PhCfg=="  # MD5 of the empty string
        p = json.loads(client.succeed(f"s3helper presign-put user1/bad.bin /tmp/small.bin {wrong}"))
        client.fail(f"curl -sSf -X PUT -H 'Content-MD5: {wrong}' --upload-file /tmp/small.bin '{p['url']}'")
        # A presigned URL reused for another key.
        p = json.loads(client.succeed("s3helper presign-put user1/ok.bin /tmp/small.bin"))
        forged = p["url"].replace("user1/ok.bin", "user1/other.bin")
        client.fail(f"curl -sSf -X PUT -H 'Content-MD5: {p['md5']}' --upload-file /tmp/small.bin '{forged}'")
        client.fail("s3helper head user1/bad.bin")
        client.fail("s3helper head user1/other.bin")

    with subtest("Video: multipart upload with presigned part URLs"):
        client.succeed("head -c 12M /dev/urandom > /tmp/video.mp4")
        client.succeed("split -b 5M -d /tmp/video.mp4 /tmp/video.part.")
        upload_id = client.succeed("s3helper mpu-create user1/video.mp4").strip()
        etags = []
        for i, part in enumerate(["00", "01", "02"], start=1):
            url = client.succeed(f"s3helper presign-part user1/video.mp4 {upload_id} {i}").strip()
            hdrs = client.succeed(f"curl -sSf -o /dev/null -D - -X PUT --upload-file /tmp/video.part.{part} '{url}'")
            etag = next(l.split(":", 1)[1].strip() for l in hdrs.splitlines() if l.lower().startswith("etag:"))
            etags.append(etag)
        client.succeed(f"s3helper mpu-complete user1/video.mp4 {upload_id} " + " ".join(f"'{e}'" for e in etags))
        assert json.loads(client.succeed("s3helper head user1/video.mp4"))["size"] == 12 * 1024 * 1024
        assert get_presigned_sha("user1/video.mp4") == sha("/tmp/video.mp4")

    with subtest("Delete works"):
        client.succeed("aws-ente s3 rm s3://ente/user1/photo.jpg")
        client.fail("s3helper head user1/photo.jpg")

    with subtest("Data survives a Garage restart, and metadata snapshots work"):
        s3.succeed("systemctl restart garage.service")
        s3.wait_for_open_port(3900)
        client.wait_until_succeeds("s3helper head user1/video.mp4", timeout=60)
        assert get_presigned_sha("user1/video.mp4") == sha("/tmp/video.mp4")
        s3.succeed("garage meta snapshot --all")
        s3.succeed("ls /var/lib/garage/meta/snapshots/ | grep -q .")

    with subtest("garage-webui logs in and lists the bucket"):
        s3.wait_for_unit("garage-webui.service")
        s3.wait_for_open_port(3909)
        api = "http://127.0.0.1:3909/api"
        s3.succeed(f"test $(curl -s -o /dev/null -w '%{{http_code}}' {api}/buckets) = 401")
        s3.fail(f"curl -sSf -c /tmp/jar -d '{{\"username\":\"admin\",\"password\":\"nope\"}}' {api}/auth/login")
        s3.succeed(f"curl -sSf -c /tmp/jar -d '{{\"username\":\"admin\",\"password\":\"test-password\"}}' {api}/auth/login")
        buckets = json.loads(s3.succeed(f"curl -sSf -b /tmp/jar {api}/buckets"))
        print(json.dumps(buckets, indent=2))
        assert "ente" in json.dumps(buckets), buckets
        objs = s3.succeed(f"curl -sSf -b /tmp/jar {api}/browse/ente?prefix=user1/")
        assert "video.mp4" in objs, objs
        s3.succeed("curl -sSf http://127.0.0.1:3909/ | grep -qi '<html'")

    s3.succeed("free -m >&2; systemctl show -p MemoryCurrent garage.service garage-webui.service traefik.service >&2")
  '';
}
