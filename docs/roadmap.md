# Roadmap

- [ ] OPA to prevent accidental deletion of critical resources
- [ ] Create a github action to update talosctl & kubernetes version
- [ ] Security, dont allow namespaces to talk to each other
- [ ] One more backup site / copy to achieve 3-2-1
- [ ] Import prod oracle into Terraform
- [ ] grafana perms on restore 10001
- [ ] Back up `hostdzire6tb` state to OVH S3 using native Restic, following the
  existing VolSync storage pattern:
  - qBittorrent: `/srv/qbittorrent/config` (torrent resume data). Until this
    exists, the frozen Kubernetes `qbittorrent` PVC from the cutover is the
    only copy; delete it once a restore has been tested.
  - Tdarr: `/srv/tdarr/server` and `/srv/tdarr/configs`. Test a restore before
    considering replacing `configure.py`.
  - Take consistent copies (stop the container or snapshot first) and exclude
    media, logs and the transcode cache.

## Low priority

- [ ] Evaluate a NixOS deployment workflow for reviewed Renovate/config changes:
  validate and build before activation, with approval, health checks and rollback.
  Consider automatic upgrades later; deployment remains manual for now.
