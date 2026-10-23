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
