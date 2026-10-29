# NixOS hosts

Declarative config for machines outside the Kubernetes clusters. For now that
is only `hostdzire6tb` (`hostdzire6tb.fossindia.ovh`, 163.61.31.213), the
HostDZire 6 TB storage VPS serving Oracle prod's NFS media storage and Tdarr.
It was installed with `nixos-anywhere` on 2026-10-29.

| Path | What it is |
| --- | --- |
| `flake.nix` / `flake.lock` | Pins nixos-26.05 and disko; exposes `nixosConfigurations.hostdzire6tb` |
| `hosts/hostdzire/default.nix` | Network, users, SSH, firewall, Tailscale, NFS server, node-exporter |
| `hosts/hostdzire/disko.nix` | Disk layout: GPT, 1 MiB BIOS boot, LVM `vg0` with 64 GiB ext4 `/`, 4 TiB ext4 `/srv`, about 1.8 TiB left free |
| `hosts/hostdzire/tdarr.nix` | Tdarr server + node as Podman containers, plus `tdarr-configure` |
| `hosts/hostdzire/tdarr/` | The flow script, `configure.py`, library defaults |

## Host configuration

- **Root SSH is refused** and only key logins work. `rize` (1000:1000, the
  owner of the media) has passwordless sudo. Users are immutable
  (`users.mutableUsers = false`).
- **Firewall:** public TCP is 22 only, plus Tailscale's UDP 41641. NFS (2049),
  node-exporter (9100) and the Tdarr UI (8265) are open only on `tailscale0`.
  Tailscale runs with `--netfilter-mode=nodivert`. Its default mode accepts
  everything on `tailscale0` before the NixOS firewall sees it, which left
  Tdarr's internal port 8266 reachable from the tailnet.
- **Tdarr runs from pinned image digests** under Podman with host networking,
  so the node reaches the server on loopback. Its flow and libraries are
  applied at boot by `tdarr-configure` from the files in this repo; there's no
  manual `configure.py` step.
- **The arr-stack folders** under `media/` and `torrents/` are created at boot.
  Tdarr's watchers attach at start-up and never notice a root that appears
  later.
- **Tdarr watches the libraries with inotify** (`useFsEvents: true`) instead
  of polling. The kernel raises inotify events for files written through the
  NFS server, so imports from the cluster show up within about 30 s.
- **`/srv` is its own logical volume**, and about 1.8 TiB of `vg0` stays free.
  That space is for a later LUKS-encrypted volume (e.g. Immich photos) or for
  growing `/srv` online with `lvextend -r`.
- **Root has a password for the VMware console only** (SSH refuses root). Its
  hash is not in git: it is read from `/var/lib/secrets/root-password.hash`,
  which `nixos-anywhere --extra-files` copied in.

## Open issues

- **Tdarr updates its plugins from GitHub every hour** (the VPS went from
  `87893f3f` to `64b2db67` on 2026-10-27). The flow's plugin code can change
  without a config change. Pinning it would mean seeding a fixed plugin
  checkout and stopping the updates.
- **Loudness:** the boosted track is exactly 2× (+6.0 dB) Emby's
  `-ac 2` without the boost, as specified. ffmpeg doesn't normalise this
  float downmix, so it ends up about 13.7 dB above a normalised stereo
  downmix. The manually made Prisoners copy is the same (+13.5 dB). Measured
  on Normal (2026), 20:00–22:00: peaks −5.2 dB, no clipping. Louder scenes
  could clip.

## Updating

Renovate opens lock-file maintenance PRs to refresh the nixpkgs and disko
revisions in `flake.lock`, keeping the input URLs declared in `flake.nix`.
A NixOS release upgrade can also change the nixpkgs branch in `flake.nix`.
Tdarr image tags and digests are tracked separately in `tdarr.nix`, with
server and node updates grouped into one PR for manual review. Container
updates do not change `flake.lock`.

Merging a PR only updates this repository. There is no automatic pull or
activation on the VPS; deployment remains manual.

Run from this directory:

```sh
nixos-rebuild switch --flake .#hostdzire6tb \
  --target-host rize@hostdzire6tb.fossindia.ovh --sudo
```

Reinstallation wipes the disk. The original install used `nixos-anywhere`
with the root password hash supplied through `--extra-files`; never use it
for routine updates.
