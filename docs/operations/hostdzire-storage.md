# HostDZire media storage

HostDZire is the permanent NFS storage server for media downloads and libraries.
Oracle continues to run qBittorrent, Radarr, Sonarr, and Emby. Application config
PVCs stay on TopoLVM and retain their existing VolSync backups. NFS media is not
included in those configuration backups; RAID is not a backup.

## Layout and access

- Server: HostDZire India StorageVPS #2, Ubuntu 26.04 LTS, SSH
  `root@163.61.31.57`, Tailscale hostname `hostdzire`.
- Tailscale address: `100.125.227.18`; permanent PV/PVC `hostdzire` is Bound
  in production with an advertised capacity of 900 GiB.
- Storage: a directory on the existing ext4 root filesystem, not a separate
  mounted disk. Leave room for Ubuntu, logs, and package updates.
- Production export: `/srv/nfs-data/oracle`, allowed client `100.92.137.3`
  (`oracle-prod`).
- Development is retired, as confirmed by the owner. The shared base retains
  an isolated `/srv/nfs-data/oracle-dev` path for any future revival, but that
  directory is not exported. Verify and allowlist a revived node's own
  Tailscale IP before deploying it; never point dev at the production directory.
- NFSv4.1/4.2 only, synchronous exports, all clients squashed to UID/GID 1000.
- UFW: deny incoming by default, allow SSH TCP 22, Tailscale UDP 41641, and
  TCP 2049 **only on `tailscale0`**. No public NFS or rpcbind access is needed.
- Use a static `hostdzire` PV/PVC with `Retain`, `ReadWriteMany`,
  no dynamic storage class, and mount options `nfsvers=4.2,hard,noatime`.
  The PV's advertised capacity does not enforce a server-side quota.
- The deployed shared application base mounts the whole claim at `/hostdzire` in
  qBittorrent, Radarr, Sonarr, Emby, Jellyfin, Audiobookshelf, and Qui.
  Audiobookshelf's mount is read-only. The existing `/data` claim is retained.

The production rollout is active. Flux and all consuming HelmReleases are
Ready; Jellyfin remains intentionally scaled to zero. New downloads and
movie/TV library roots use HostDZire; existing torrents and title paths were
not moved. A real qBittorrent download, a Radarr hardlink import, and an Emby
HTTP stream were verified using disposable content, then cleaned up. The owner
explicitly waived Instatus maintenance for this initial rollout; the repository's
normal maintenance policy still applies to future operations.

```text
/hostdzire/
├── torrents/
│   ├── movies/
│   ├── tv/
│   ├── audiobooks/
│   └── temp/
└── media/
    ├── movies/
    └── tv/
```

Downloads and library destinations must be below the **same mount**, not
separate exports or separate subPath mounts. An arr import can then hardlink
from `torrents/` to `media/` without copying the payload across the WAN.
Imports between `/data` and `/hostdzire` cannot hardlink.

## Server configuration

### SSH

The owner's primary `/home/rize/.ssh/id_ed25519.pub` key was added to root's
`authorized_keys` (directory mode 700, file mode 600). A fresh key-only login
was verified before and after reloading SSH. The server refuses non-key
authentication. No private key was copied to the server.

`/etc/ssh/sshd_config.d/00-key-only.conf`:

```text
PubkeyAuthentication yes
AuthenticationMethods publickey
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
```

This file precedes the image's cloud/root-login snippets because OpenSSH uses
the first value it obtains. Run `sshd -t` before `systemctl reload ssh`, inspect
`sshd -T`, and verify another key-only session before closing the current one.
Keep SSH TCP 22 allowed as break-glass access if Tailscale fails. An external
IPv4 check verified TCP 22 reachable and TCP 111/2049 unreachable.

### NFS and Tailscale

These files were installed on the server. Recreate them before restoring the
NFS service on a replacement VPS; enroll that server in Tailscale and update
the PV endpoint if its Tailscale IP changes.

`/etc/nfs.conf.d/v4only.conf`:

```ini
[nfsd]
vers3=n
vers4.0=n
vers4.1=y
vers4.2=y
```

`/etc/exports.d/hostdzire.exports`:

```text
/srv/nfs-data/oracle 100.92.137.3(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
```

Create the export directory and its children as UID/GID 1000. The export root
is mode 2775. Apply export changes with `exportfs -rav`; a version change also
requires restarting `nfs-server`. Do not restart a populated production export
without scheduling maintenance first.

Keep Tailscale machine-key expiry disabled for this dedicated storage server
in the Tailscale admin console. At enrollment the key was still set to expire
on April 24, 2027; disabling expiry requires an owner action in that console.
If ACLs restrict traffic, permit the intended
Oracle node identities to reach `hostdzire` on TCP 2049. The NFS client is the
Talos node, not the application pod. Do not add NFS exceptions to Gluetun or
route qBittorrent traffic around its VPN: the node mounts NFS separately.

## Rollout and application paths

1. Approve Tailscale enrollment for `hostdzire`. Record `tailscale ip -4` as the
   PV server address, verify `tailscale ping 100.92.137.3`, and confirm a direct
   connection rather than sustained DERP relay use.
2. Validate the export from an isolated pod before rolling application pods:
   NFSv4.2 mount, UID/GID 1000 write access, hardlinks across `torrents/` and
   `media/`, sequential reads, and buffered writes within qBittorrent's memory
   budget. Wait for any independent disk benchmark to finish first.
3. Schedule Instatus maintenance for Emby and the affected media services before
   restarting them. If API access is unavailable, have the owner schedule it
   and confirm before proceeding. Complete it only after health checks pass.
   The owner explicitly waived this step for the initial HostDZire rollout.
4. Deploy the PV/PVC before the application HelmRelease changes. Keep the PV,
   claim, and application mounts in the shared base; only the per-cluster
   export path differs between overlays. Development is retired. Before any
   future revival, enroll its node and configure its isolated export first.
5. Verify Helm has rendered `/hostdzire` and `/data` in all consuming applications,
   the claim is Bound, and the restarted pods are Ready.
6. Set qBittorrent's default save path to `/hostdzire/torrents` and, if used,
   temporary path to `/hostdzire/torrents/temp`. Check category paths for
   `movies`, `tv`, and `audiobooks`; no category should direct new downloads
   back to `/data`. Disable automatic relocation triggers while changing
   defaults so existing torrents are not moved implicitly. Confirm their
   existing save paths remain unchanged afterward.
7. Add `/hostdzire/media/movies` as a Radarr root and `/hostdzire/media/tv` as a
   Sonarr root. Keep **Use Hardlinks instead of Copy** enabled. Choose these
   roots for new titles, including Seerr's default roots if Seerr submits them.
   Keep qBittorrent categories consistent with each arr download client. No
   remote-path mapping is needed when all apps see `/hostdzire` identically.
8. Add the new media directories to the appropriate existing Emby libraries.
   Retain current `/data` library paths until existing media is explicitly
   migrated. Keep Emby's config and transcode-temp settings unchanged during
   this storage rollout; verify no stale `/nfs-data` path remains from earlier
   experimentation. Add corresponding library paths in Jellyfin and
   Audiobookshelf when those services should index new HostDZire content.
9. Verify a completed qBittorrent download on NFS, an arr hardlink import, and
   Emby streaming. The initial rollout used separate disposable fixtures for
   these checks, as described below. Check the first normal automated arr import
   too; manual import validation does not exercise automatic download matching.
   Do not silently migrate or delete existing local media or torrent payloads.

### Applied production settings

- qBittorrent default save path: `/hostdzire/torrents`. Categories `movies`,
  `tv`, and `audiobooks` use the corresponding children of that directory.
  Its temporary path is `/hostdzire/torrents/temp`; temporary-folder use remains
  disabled, preserving the previous preference.
- Automatic torrent management remains enabled for new torrents. It was
  disabled individually for the three existing torrents before changing paths;
  their `/data/torrents/...` locations remain unchanged. Re-enable it for those
  torrents only when intentionally relocating them.
- Radarr root: `/hostdzire/media/movies` (ID 3); Sonarr root:
  `/hostdzire/media/tv` (ID 2). Both retain their old `/data` roots and existing
  title paths, with `copyUsingHardlinks=true`.
- Seerr's existing Radarr and Sonarr server settings now select these HostDZire
  roots for new requests. Other Seerr integration settings were left unchanged.
- Emby's existing Movies and TV shows libraries include the new movie/TV roots
  alongside their original `/data` paths. The stale `/nfs-data/movies` location
  was removed. No config or transcode-temp path was relocated.
- Jellyfin remains disabled. Audiobookshelf has read-only filesystem access;
  no new Audiobookshelf library was created during this movie/TV rollout.

### Application verification

qBittorrent downloaded the official Debian 13.7 arm64 netinst image
(735,358,976 bytes, 701.3 MiB) into its new default path in 89 seconds. Its
SHA-256 matched Debian's published checksum. A hardlink from the completed
download into `media/` shared the same inode with link count 2. No app restarts
or OOM events occurred. The torrent and both file links were removed afterward.
The VPN binding remained `tun0`; no firewall or VPN exception was introduced.

Separately, a generated 120-second video was imported through Radarr's
`ManualImport` command with copy mode and hardlinks enabled into a disposable,
unmonitored movie entry on the new root. The source and imported 13,175,575-byte
file had the same inode and link count 2. Emby indexed the imported file and
served an authenticated static HTTP range; its first 1 MiB matched the file's
SHA-256. Emby's decoder also decoded a generated NFS clip successfully.
The temporary movie entry and generated content were removed and the library
refreshed. This verifies storage/import/streaming primitives, not a browser
playback session, Sonarr episode import, or a full automated torrent-to-arr flow.

Production Kubernetes/Talos commands run from `clusters/prod` with mise:

```bash
mise exec -- kubectl -n homelab get pvc hostdzire
mise exec -- kubectl -n homelab get deployments emby qbittorrent radarr sonarr
mise exec -- kubectl -n homelab exec deployment/qbittorrent -c app -- df -h /hostdzire
mise exec -- kubectl -n homelab exec deployment/emby -- sh -c 'grep /hostdzire /proc/mounts'
```

## Memory and bandwidth

Before NFS integration, qBittorrent's app container had request=limit **1 GiB**.
The preceding 14 days showed a peak working set of 194,396,160 bytes
(185.4 MiB), peak RSS 114,753,536 bytes (109.4 MiB), and peak total usage
4,295,819,264 bytes (about 4 GiB), from separate VictoriaMetrics maxima.
Those peaks need not occur at the same time and do not establish NFS needs.

The baseline disk-I/O write mode enabled OS caching. A 4 GiB buffered NFS fio
write in an isolated **1 GiB** pod reproduced `OOMKilled`, confirmed by the pod
status and Talos kernel logs. Raising a 512 MiB limit to 1 GiB is not a fix.

qBittorrent has now been set to **WriteThrough** (`disk_io_write_mode=2`) through
its API, retaining request=limit 1 GiB. Its installed libtorrent is 2.0.15 and
its backend is Simple pread/pwrite. The
[qBittorrent implementation](https://github.com/qbittorrent/qBittorrent/blob/release-5.2.4/src/base/bittorrent/sessionimpl.cpp)
uses the mmap backend with pread/pwrite fallback; libtorrent's
[mmap storage](https://github.com/arvidn/libtorrent/blob/v2.0.15/src/mmap_storage.cpp)
maps WriteThrough to `open_mode::no_cache`, which
[opens files with `O_SYNC` on Linux](https://github.com/arvidn/libtorrent/blob/v2.0.15/src/file.cpp).
This is synchronous buffered I/O, **not `O_DIRECT`**.

A subsequent 4 GiB `fio --ioengine=sync --direct=0 --sync=1 --bs=1M` write
completed at 17.73 MiB/s in the same 1 GiB budget with zero OOM events.
Clean cache reached the cgroup limit and was reclaimed; dirty-page accumulation
did not kill the pod. This validates the I/O primitive, not actual concurrent
qBittorrent download throughput. WriteThrough trades throughput for bounded
dirty data; torrent block sizes/concurrency differ from this fio workload.

The real Debian download above subsequently completed within the existing
1 GiB limit, averaging about 7.9 MiB/s including startup. Five-second samples
observed up to approximately 785 MiB total cgroup usage, including clean file
cache and validation processes; all `memory.events` OOM counters remained zero.
A mid-download snapshot had zero dirty bytes and 160 KiB in writeback. Keep
request=limit **1 GiB** rather than increasing memory without evidence. This
single-download result is not a concurrency or sustained-throughput guarantee;
measure working set, dirty data, and OOM/restart counters under normal load.

Restore/verify the setting through qBittorrent's preferences API or Advanced
settings when restoring its configuration. Keep it in place before moving
downloads to NFS. Do not assume low RSS makes buffered NFS writes safe or
replace this setting with an unmeasured memory-limit increase.

The monthly 2 TB allowance counts both ingress and egress. Writing a 20 GB
download and reading it once for direct play is approximately 40 GB before
other traffic. Repeated reads, torrent seeding, migration, and remote transcode
scratch add traffic. Monitor usage in the provider panel and keep seeding
limits appropriate to that budget.

Local-disk measurements and cache caveats are recorded in
[Storage benchmark](storage-benchmark.md#hostdzire-india-storagevps-2--october-26-2026).
They are not measurements of the NFS/WAN path.

## Outages, recovery, and rollback

`hard` mounts retry through temporary outages rather than returning partial
I/O errors. Applications can stall while NFS is unavailable; their processes
may enter uninterruptible I/O wait, and a restart may not complete until the
server or network recovers. Do not switch to `soft` to make pods terminate.

Check on the Ubuntu server:

```bash
tailscale status
tailscale ping 100.92.137.3
systemctl status tailscaled nfs-server
exportfs -v
cat /proc/fs/nfsd/versions
ufw status verbose
df -h /
```

After recovery, check pod readiness, restart/OOM counts, a small read and write,
and Emby playback before closing maintenance. Preserve the PV's `Retain` policy
and the underlying export if removing the PVC.

For rollback, first stop new downloads/imports and restore application path
settings to `/data`. Existing HostDZire payloads are not present on `/data`;
copy or explicitly relocate those before removing their mount or library paths.
Remove only the `hostdzire` persistence entries from the consuming HelmReleases and
reconcile Helm under maintenance. Do not delete either storage tree.

Resuming a suspended Flux resource does **not** by itself undo a manual
Deployment patch when Helm sees no release change. Revert such patches
explicitly or force a Helm upgrade, then inspect the rendered pod mounts and
confirm the HelmRelease is Ready. Prefer deploying the actual HelmRelease
values rather than patching the Deployment directly.
