# hostdzire6tb: HostDZire StorageVPS (WebWerks Mumbai). NFS storage for the
# Oracle cluster, reached over Tailscale, plus Tdarr. VMware ESXi guest,
# 4 vCPU, 8 GiB RAM, 6 TB, BIOS boot, LSI Logic SCSI, vmxnet3. No swap.
{ lib, pkgs, ... }:
{
  imports = [
    ./disko.nix
    ./tdarr.nix
  ];

  system.stateVersion = "26.05";
  networking.hostName = "hostdzire6tb";
  time.timeZone = "UTC";

  boot.loader.grub.enable = true; # devices come from the disko EF02 partition
  # The disk sits on VMware's LSI Logic controller (mptspi); keep PVSCSI too
  # in case the provider changes the virtual hardware.
  boot.initrd.availableKernelModules = [
    "mptspi"
    "vmw_pvscsi"
    "ahci"
    "ata_piix"
    "sd_mod"
    "sr_mod"
  ];
  virtualisation.vmware.guest.enable = true;

  # Static addressing; the provider has no DHCP.
  networking.useDHCP = false;
  networking.useNetworkd = true;
  systemd.network.networks."10-wan" = {
    matchConfig.MACAddress = "00:50:56:bf:b8:db";
    address = [
      "163.61.31.213/24"
      "2400:5c60:3::2326:1/64"
    ];
    routes = [
      { Gateway = "163.61.31.1"; }
      { Gateway = "2400:5c60:3::1"; }
    ];
    dns = [
      "1.1.1.1"
      "1.0.0.1"
      "2606:4700:4700::1111"
      "2606:4700:4700::1001"
    ];
    networkConfig.IPv6AcceptRA = false;
    linkConfig.RequiredForOnline = "routable";
  };

  users.mutableUsers = false;
  # Console-only fallback (SSH refuses root). The hash is not in git:
  # nixos-anywhere copies it in with --extra-files; see nixos/README.md.
  users.users.root.hashedPasswordFile = "/var/lib/secrets/root-password.hash";
  users.groups.rize.gid = 1000;
  users.users.rize = {
    uid = 1000;
    group = "rize";
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICiUB1MgFciQ63LsGGBwHVjCtf1cn50BdxN9jTtfTPGF rize@legion"
    ];
  };
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AuthenticationMethods = "publickey";
    };
  };

  # Public: SSH and Tailscale's direct UDP port. Everything else only on the tailnet.
  networking.firewall = {
    allowedTCPPorts = [ 22 ];
    interfaces.tailscale0.allowedTCPPorts = [
      2049 # NFS
      9100 # node-exporter
      8265 # Tdarr UI
    ];
  };

  services.tailscale = {
    enable = true;
    port = 41641;
    openFirewall = true;
    # By default tailscaled jumps to its own chain first and accepts
    # everything arriving on tailscale0, which makes the per-interface rules
    # above meaningless. nodivert keeps its chains but leaves filtering to
    # this firewall.
    extraSetFlags = [ "--netfilter-mode=nodivert" ];
  };

  services.nfs = {
    server = {
      enable = true;
      # Only oracle-prod on the tailnet may mount this export.
      exports = ''
        /srv/nfs-data/oracle 100.92.137.3(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
      '';
    };
    settings = {
      nfsd = {
        vers3 = false;
        "vers4.0" = false;
        "vers4.1" = true;
        "vers4.2" = true;
      };
      mountd.manage-gids = true;
    };
  };

  systemd.tmpfiles.settings."10-srv" = {
    "/srv/nfs-data".d = {
      user = "rize";
      group = "rize";
      mode = "2775";
    };
    "/srv/nfs-data/oracle".d = {
      user = "rize";
      group = "rize";
      mode = "2775";
    };
  }
  # The folders the arr-stack apps expect. Tdarr's folder watchers attach at
  # start-up and never notice a library root that appears later, so these
  # must exist before it starts.
  //
    lib.genAttrs
      (map (d: "/srv/nfs-data/oracle/${d}") [
        "media"
        "media/books"
        "media/movies"
        "media/music"
        "media/tv"
        "torrents"
        "torrents/audiobooks"
        "torrents/books"
        "torrents/movies"
        "torrents/music"
        "torrents/temp"
        "torrents/tv"
      ])
      (_: {
        d = {
          user = "rize";
          group = "rize";
          mode = "2775";
        };
      });

  # Scraped by the cluster's VMStaticScrape over the tailnet.
  services.prometheus.exporters.node = {
    enable = true;
    port = 9100;
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [ "@wheel" ];
  };
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  };
  environment.systemPackages = with pkgs; [
    htop
    iotop
  ];
}
