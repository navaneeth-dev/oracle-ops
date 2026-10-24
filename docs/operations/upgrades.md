# Upgrades

Renovate opens and merges update PRs through a dedicated GitHub App.

Prod is updated roughly every three months. Test changes on the dev cluster
first.

## Talos image and system extensions

`talos-schematic.yaml` at the repository root lists the system extensions.
`task common:genconfig` and `task common:upgrade` post it to the Image Factory,
which returns the same content-addressed ID for the same file, and use
`factory.talos.dev/oracle-installer/<id>:<version>`.

To change extensions, edit the schematic, then from `clusters/<cluster>/talos`:

1. `task common:genconfig` and `task common:applyconfig` (no reboot).
2. `task common:upgrade` (reboots the node; extensions only change here).
3. `talosctl get extensions` shows the new schematic ID.

Always upgrade through the task. A `talosctl upgrade` with another installer
image silently removes the extensions.

Each cluster's `multidoc/tailscale.sops.yaml` holds its Tailscale
`ExtensionServiceConfig`, using a `tag:talos` OAuth client secret.

Rollback options:

- `talosctl rollback`
- OCI console boot volume rollback
