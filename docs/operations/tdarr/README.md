# Tdarr on the HostDZire storage VPS

Tdarr adds a boosted stereo track to every movie and TV file, so the Emby
Android app direct-plays a loud stereo track instead of downmixing DTS/5.1
itself. It runs as NixOS-managed Podman containers on `hostdzire6tb`, outside
Kubernetes, so transcoding uses local storage rather than transferring media
over NFS.

- UI: <http://100.124.57.7:8265>, on Tailscale only, with no authentication.
- Host: `rize@hostdzire6tb.fossindia.ovh` (HostDZire StorageVPS, 4 vCPU, 8 GiB RAM).
  SSH is key-only and root login is disabled; `rize` has passwordless sudo.
- Files: [tdarr.nix](../../../nixos/hosts/hostdzire/tdarr.nix) (containers and boot-time configuration),
  [add-boosted-stereo.js](../../../nixos/hosts/hostdzire/tdarr/add-boosted-stereo.js) (flow logic),
  [configure.py](../../../nixos/hosts/hostdzire/tdarr/configure.py) (creates the flow and libraries through the API)
  and [library-defaults.json](../../../nixos/hosts/hostdzire/tdarr/library-defaults.json) (Tdarr 2.96.01 library
  defaults, used by `configure.py`).

## Setup

| Item | Value |
| --- | --- |
| Images | `ghcr.io/haveagitgat/tdarr` and `tdarr_node`, both pinned to `2.96.01` |
| Server | `tdarr`, capped at 768 MiB; host networking with the firewall allowing the web UI (8265) only on `tailscale0` |
| Node | `tdarr-node` (`hostdzire`), capped at 1 GiB and 1.5 CPUs; one CPU transcode worker, no health-check workers |
| State | `/srv/tdarr/{server,configs,logs}` |
| Cache | `/srv/tdarr/cache`, on the local disk |
| Media | `/srv` is bind-mounted at `/srv` in both containers, so libraries use the host paths `/srv/nfs-data/oracle/media/{movies,tv}`. With a single mount, the final cache-to-library move is a rename instead of a copy. |
| Ownership | `PUID`/`PGID` 1000 (`rize`), the same as the media; the NFS export squashes clients to it. Replacement files are set to 0644. |
| Boot | NixOS generates `podman-tdarr` and `podman-tdarr-node` systemd services. `tdarr-configure` applies the flow and libraries once the server API is ready. |

Both libraries watch their folders with inotify (`useFsEvents: true`) and
also scan on start. NFS writes trigger inotify events on the storage host.
Only `.mkv` files are considered. New files wait 10 minutes (hold) so
Radarr and Sonarr can finish importing. The hardlink filter is off because
library files are hardlinks of the seeding torrents.

## Flow: "Boosted stereo track"

```diagram
┌────────────┐   ┌─────────────────────────┐ 1 ┌──────────────────┐ 1 ┌─────────┐   ┌──────────────┐
│ Input File │──▶│ Add boosted stereo (JS) │──▶│ Duration matches │──▶│ Replace │──▶│ chmod 644    │
└────────────┘   └────────────┬────────────┘   └────────┬─────────┘   │ original│   └──────────────┘
                              │ 2: skip                 │ 2/3         └─────────┘
                              ▼                         ▼
                         (not required)            Fail Flow
```

`add-boosted-stereo.js` skips the file when any of these is true:

- It isn't an `.mkv`.
- It has no non-commentary audio.
- It already has a non-commentary audio track with 2 or fewer channels.
- It is a manual `… - Stereo.mkv` copy, or one sits next to it, as for
  Prisoners (2013).

Otherwise it runs ffmpeg into the cache:

- **Video, original audio and attachments:** stream-copied.
- **New first track:** AAC 192k 2.0, `-ac 2 -filter:a volume=2` (the same as
  Emby). Source preference is English default, English, default, then first
  non-commentary audio track. It is titled `Stereo (boosted)`, tagged with the source
  language, and is the default track.
- **Original audio tracks:** kept after it, all non-default.
- **Subtitles:** only English ones are kept.

The output keeps the same file name and the `.mkv` container. Its duration
must be within 99.5–100.5% of the original before it replaces the original in
place. Replacing breaks the hardlink to the torrent copy, so that file now uses
its own disk space. Radarr and Sonarr keep the file record and quality, and
pick up the new size and media info on their next rescan.

## Operations

- **Status:** check the UI, or run `sudo systemctl status podman-tdarr podman-tdarr-node` on the VPS.
  Container logs are available with `sudo journalctl -u podman-tdarr -u podman-tdarr-node`.
  Job logs are in `/srv/tdarr/server/Tdarr/DB2/JobReports/`.
- **Requeue a file:** open the Library tab, find the file and choose Requeue.
  Processed files are skipped anyway because they already have a stereo track.
- **After processing:** rescan in Radarr or Sonarr if the file size matters to
  you, then refresh the Emby library. Emby also picks up changes on its next
  scheduled scan.

## Updates and recovery

Renovate opens a grouped PR for the server and node image tags/digests in
`tdarr.nix`; these updates are not auto-merged. After reviewing and merging,
manually apply the [NixOS configuration](../../../nixos/README.md#updating).
Changes to the flow script or library defaults trigger `tdarr-configure` on
the next activation; it also runs at boot. There is no Compose deployment to
update separately.

`configure.py` recreates the flow and libraries, not processing history or all
application state. Recovery also needs a consistent backup of
`/srv/tdarr/server` and `/srv/tdarr/configs`; logs and transcode cache need not
be restored. Off-host backups are not yet configured in this NixOS setup.
