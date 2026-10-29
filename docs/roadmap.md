# Roadmap

- [ ] Migrate all helm repo app-template to oci
- [ ] Monitor authentik uptime either VMServiceScrape or VMProbe
- [ ] OPA to prevent accidental deletion of critical resources
- [ ] Create a github action to update talosctl & kubernetes version
- [ ] Security, dont allow namespaces to talk to each other
- [ ] Trivy scan k8s, terraform everything
- [ ] One more backup site / copy to achieve 3-2-1
- [ ] grafana perms on restore 10001

## Low priority

- [ ] Back up Tdarr state on `hostdzire6tb` to OVH S3 using native Restic,
  following the existing VolSync storage pattern. Back up consistent copies of
  `/srv/tdarr/server` and `/srv/tdarr/configs` and test restoration before
  considering replacing `configure.py`; exclude media, logs and transcode cache.
- [ ] Evaluate a NixOS deployment workflow for reviewed Renovate/config changes:
  validate and build before activation, with approval, health checks and rollback.
  Consider automatic upgrades later; deployment remains manual for now.
