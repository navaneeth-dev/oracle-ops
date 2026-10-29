# One 6 TB VMware disk, booted by SeaBIOS: GPT with a BIOS boot partition for
# GRUB, the rest LVM. / and /srv are logical volumes; the rest of the volume
# group stays free so an encrypted (LUKS) volume, e.g. for Immich, can be
# added later without reinstalling, and /srv can grow online (lvextend -r).
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          bios = {
            size = "1M";
            type = "EF02";
            priority = 1;
          };
          lvm = {
            size = "100%";
            content = {
              type = "lvm_pv";
              vg = "vg0";
            };
          };
        };
      };
    };
    lvm_vg.vg0 = {
      type = "lvm_vg";
      lvs = {
        root = {
          size = "64G";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
            extraArgs = [ "-L" "nixos" ];
          };
        };
        srv = {
          size = "4T";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/srv";
            mountOptions = [ "noatime" ];
            extraArgs = [ "-L" "srv" ];
          };
        };
      };
    };
  };
}
