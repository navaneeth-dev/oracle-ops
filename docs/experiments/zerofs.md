# ZeroFS limitations

ZeroFS (S3-backed filesystem over 9P, on OVH Object Storage) was tried as media
storage for the arr stack in October 2026 and removed.

1. **Does not fit the torrenting use case.** Torrents write and read small
   blocks in random order. Downloads averaged ~10 MiB/s on ZeroFS against
   ~36 MiB/s on local disk, and seeding reads were slow.

2. **Consumes memory unnecessarily.** The gateway needed a 4 GiB memory
   reservation on an already full node. Background cleanup after deletes was
   OOMKilled at 2 GiB, which hung every mount.

3. **Is not reliable.** A single gateway serves every mount, so any gateway
   restart stalls qBittorrent, Sonarr, Radarr and Emby together. After a
   restart, files that were already open fail with `Bad file descriptor`
   until each app pod is recreated.

4. **Disconnects with S3 cause issues.** A short S3 delay makes the gateway
   stop itself (`HA writer was fenced or superseded`). The timeout is fixed in
   ZeroFS and cannot be configured, so a brief network hiccup stops seeding
   and breaks playback.

## Benchmarks

| Test | ZeroFS | Local disk (`/data`) |
| --- | ---: | ---: |
| Sequential write, 8 GiB (fio, 32 MiB/s cap) | 31.7 MiB/s | — |
| Sequential read, 8 GiB (fio, 32 MiB/s cap) | 32.0 MiB/s | — |
| Random read 128 KiB, 1 worker (fio) | 2.9 MiB/s | — |
| Random read 128 KiB, 4 workers (fio) | 15.6 MiB/s | — |
| Real torrent download, same swarm | ~10.7 MiB/s | ~36 MiB/s |
| Emby-style uncached read, 1 MiB blocks | 17–32 MB/s | — |

The fio runs were capped at 32 MiB/s, so the sequential results hit the cap
and do not show maximum throughput.

## Architecture

```
qBit / Sonarr / Radarr / Emby
        │ normal file I/O on /zerofs
        ▼
FUSE mount (inside the zerofs-csi-node pod)
        │ 9P over TCP, port 5564
        ▼
zerofs-gateway-a  ── S3 API over HTTPS ──→ OVH Object Storage (Mumbai)
        ▲
        │ admin RPC, port 7000 (creates and deletes volumes)
zerofs-csi-controller
```
