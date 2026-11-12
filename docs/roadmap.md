# Roadmap

- [ ] OPA to prevent accidental deletion of critical resources
- [ ] Create a github action to update talosctl & kubernetes version
- [ ] Security, dont allow namespaces to talk to each other
- [ ] One more backup site / copy to achieve 3-2-1
- [ ] Import prod oracle into Terraform
- [ ] grafana perms on restore 10001
- [ ] Decide Homepage's future: it is public and duplicates Authentik's app
  library. Either strip it to a landing page (Authentik sign-in link and status
  badge) or remove it and redirect the apex and `start.` domains to Authentik.
- [ ] Back up `hostdzire6tb` state to OVH S3 using native Restic, following the
  existing VolSync storage pattern:
  - qBittorrent: `/srv/qbittorrent/config` (torrent resume data). Until this
    exists, the only older copy is the last VolSync snapshot (November 9,
    04:30 IST, before the cutover) in the `qbittorrent` restic repository of
    the `oracle-volsync` bucket.
  - Tdarr: `/srv/tdarr/server` and `/srv/tdarr/configs`. Test a restore before
    considering replacing `configure.py`.
  - Take consistent copies (stop the container or snapshot first) and exclude
    media, logs and the transcode cache.

## Low priority

- [ ] Evaluate a NixOS deployment workflow for reviewed Renovate/config changes:
  validate and build before activation, with approval, health checks and rollback.
  Consider automatic upgrades later; deployment remains manual for now.
