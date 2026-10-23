# ZeroFS limitations observed in production

ZeroFS (gateway image `ghcr.io/barre/zerofs@sha256:2078…`, CSI v2.3.5) ran on the
production Oracle cluster on 22–23 October 2026 as shared storage for qBittorrent,
Sonarr, Radarr and Emby. It used a single standalone gateway, an 8 GiB TopoLVM
cache claim (6 GB disk cache, 0.5 GB memory cache) and OVH Object Storage in
Mumbai (`s3://rizexor-media/zerofs`). This records what failed, with the measured
numbers, so the decision to remove it can be revisited with evidence.

## Summary

| Area | Result |
| --- | --- |
| Sequential reads (Emby playback) | Worked: 17–32 MB/s uncached, against ~2.3 MB/s for an 18 Mbit/s Blu-ray |
| Hardlinks (torrent → library import) | Worked: same inode, link count 2 |
| Torrent downloads (random writes) | Poor: ~10.7 MiB/s average, against ~36 MiB/s on local disk with the same swarm |
| Seeding (random reads) | Poor: 2.85 MiB/s uncached random reads in the benchmark |
| Availability | Unacceptable: two outages in one day, both requiring manual recovery |

## Limitations

### 1. Random-write throughput

A torrent written directly to ZeroFS averaged 10.7 MiB/s. qBittorrent reported
25% write cache overload, 162 queued I/O jobs and an average queue time of
3,583 ms. The same swarm delivered ~36 MiB/s to local `/data`. BitTorrent writes
16 KiB blocks out of order, and each write waits on FUSE → 9P → gateway → S3. The
historical fio benchmark (sequential, direct I/O, 32 MiB/s cap) does not
represent this workload.

### 2. Segment reclamation memory and OOM crash loop

Overwriting and deleting data leaves dead segments, which the gateway reclaims in
the background with `[reclaim] max_concurrent_repacks = 4` jobs, each gathering up
to 256 MiB (1 GiB aggregate) on top of the memory cache. Moving a partial 14.8 GB
torrent onto ZeroFS (written densely, including unfilled regions) and then
deleting it produced ~14 GiB of dead data. At a 2Gi memory limit the gateway was
OOMKilled ~18 seconds after every start, because reclamation resumed on startup.
Every `/zerofs` mount hung until the limit was raised to 4Gi. Peak memory after
the change was ~1.76 GiB.

### 3. HA serving lease fences a standalone gateway

The gateway config contained `[replication] node_id = "node-a"`,
`role = "leader"`, a leftover from the two-gateway trial. The gateway stopped
itself after a brief object-store delay:

```
WARN  HA serving authority expired; responses suspended during final ownership validation
ERROR Tombstone cleanup failed: IoError
ERROR HA final Active ownership validation timed out; stepping down
✗ Error: HA writer was fenced or superseded; restart required
```

The ZeroFS documentation lists the serving-authority grant (3 s) and marker
validation timeouts (3 s) as "release policy, not configuration knobs", so the
lease cannot be made more tolerant. The docs say a standalone leader may omit
the peer settings, but do not say whether removing `[replication]` disables the
lease for a filesystem that already has an ownership marker. Untested.

### 4. Stale file handles after a gateway restart

After the gateway restarted, the CSI node plugin logged
`9P connection lost; reconnecting and replaying session…` for every mount.
Directory listings and new files worked, but any file that a pod had opened before
the restart failed to open with `Bad file descriptor`, in Emby, Radarr and
qBittorrent. A pod that had not opened the file (Sonarr) could still read it.
Emby buffered indefinitely, and qBittorrent's torrent entered an error state, so
seed time stopped counting. Only recreating each pod cleared it. The HA docs
describe rebinding open files only after a takeover in an HA pair; a plain
single-gateway restart is not covered.

### 5. Single point of failure

One gateway served every mount. Any gateway outage (OOM, fencing, rollout) hung
I/O in all consuming pods at once, including `kubectl exec` commands touching
`/zerofs`. The CSI node plugin uses FUSE with an `OnDelete` update strategy;
restarting it breaks active mounts until consuming pods are recreated.

### 6. Object-store space amplification and delayed reclaim

With 13.8 GiB of live data the bucket held 27.8 GiB (864 objects, 26.97 GiB of
segments), 51% dead. Reclamation brought it down over roughly 30 minutes.
Deletions free object storage only after reclamation, and reclamation itself
reads and rewrites data, adding requests and traffic.

### 7. No sparse files after a cross-filesystem move

qBittorrent's category move copied a 37%-complete torrent onto ZeroFS as a full
14 GB file, unfilled regions included, so `df` showed the full size as used.
Most of the earlier progress was then re-downloaded. Moving partial torrents onto
ZeroFS is expensive in time, space and reclamation work.

### 8. Opaque storage format

Data is stored as encrypted, compressed segments inside SlateDB. Files cannot be
read from the bucket directly, only through a running gateway with the encryption
password. There is no fallback access path during a gateway outage.

### 9. Backend changes need careful handling

Switching the gateway's object prefix opens a new, empty filesystem. A local
cache populated from the previous prefix had to be cleared by an init container
before startup. Existing PVs bound to the old prefix (benchmark claims) had to be
deleted. Volumes cannot migrate between prefixes.

## Operational issues encountered (not ZeroFS defects)

- **Flux substitution race:** the overlay patch adding
  `postBuild.substitute.ZEROFS_STORAGE_URL` and the manifests using it landed in
  the same push. The `zerofs` Kustomization reconciled the new manifests with its
  old spec, so the gateway received the literal `${ZEROFS_STORAGE_URL}`. The cache
  initializer's guard refused to start, preventing damage. Push spec changes and
  dependent manifests separately.
- **StatefulSet rollout stuck on a crash-looping pod:** with `OrderedReady`, the
  updated 4Gi revision was not rolled out until the failing pod was deleted.
- **Variable substitution reaches decrypted Secrets:** enabling `postBuild.substitute`
  also substitutes SOPS-decrypted Secret values; the credentials Secret needed
  `kustomize.toolkit.fluxcd.io/substitute: disabled`.

## Conclusion

ZeroFS handled sequential reads and hardlinks well, but the arr workload needs
reliable random writes, random reads for seeding, and uninterrupted availability
for seed time and playback. Issues 3 and 4 together mean any short object-store
delay can stop seeding and break playback until pods are restarted by hand. It
was removed; downloads, seeding and the library stay on local disk (`/data` on
Oracle for now, with a dedicated media node under consideration).

References: [ZeroFS high availability](https://www.zerofs.net/docs/high-availability),
[ZeroFS configuration](https://www.zerofs.net/docs/configuration),
[ZeroFS durability](https://www.zerofs.net/docs/durability).
