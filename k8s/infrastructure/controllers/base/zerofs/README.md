# ZeroFS CSI storage

Shared infrastructure, included by both production and dev controller overlays.
The arr integration is documented in [arr-stack](../../../../apps/base/arr-stack/README.md).
Emby is unchanged; do not drain/reboot the node or restart Emby for storage checks.

## Storage and resource budget

- Backends: production `s3://rizexor-media/zerofs`, dev
  `s3://rizexor-media/zerofs-dev`, OVH Mumbai (`ap-south-mum`). Each controller overlay
  sets `spec.postBuild.substitute.ZEROFS_STORAGE_URL` on the `zerofs` Flux
  Kustomization. Flux writes this value directly into the gateway environment,
  so changing it triggers a pod rollout. There is no base backend default; each
  overlay must supply its URL. ZeroFS isolates local caches using a filesystem UUID
  stored in `.zerofs_bucket_id` at the backend database path. Each filesystem uses
  its own `bucket_<id>` directory under the cache root. Backend changes therefore
  do not need a custom cache initializer. Orphaned cache directories are not
  automatically removed; reclaim their disk space manually with the gateway
  stopped if needed. Historical benchmarks used the separate `zerofs-test` prefix,
  retained without migration. This is ZeroFS's internal object format, separate
  from existing media object keys.
- `secret-ovh.yaml` reuses the endpoint/access key/secret key from Sonarr's disabled
  upload integration, encrypted with the repository's SOPS recipient. It has a
  separate generated ZeroFS password. Keep that encrypted password to reopen data.
  Sonarr's upload hook and Discord webhook are not enabled or copied.
  Flux substitution is disabled on this Secret so credential values containing
  `${...}` remain literal after SOPS decryption.
- One standalone gateway with an **8 GiB TopoLVM cache PVC**, **6 decimal GB disk cache**,
  and **0.5 decimal GB memory cache**. No VolSync or backup component is used.
- The cache budget includes metadata and file data. A 20 GiB file need not fit
  locally. Reads outside cache fetch object data from OVH.
- Initial physical thin-pool measurement: 160,897,695,744 bytes, 75.77% used,
  approximately 36.3 GiB free. Filling one 8 GiB claim leaves about 28.3 GiB
  of physical headroom, before other workloads grow. Thin PVC capacity is not
  a measurement of physical free space.
- Gateway CPU request: 250m; no CPU limit, allowing bursts. Memory request and
  limit: 2Gi, based on observed usage around 1.0–1.4 GiB plus headroom. These are bounded **trial values**, not upstream sizing
  recommendations. Check throttling and memory before selecting production values.
  The manual benchmark used temporary 25m gateway requests to fit the current
  scheduler budget; the current memory limit remains 2Gi. CSI memory requests
  equal limits (64Mi per small sidecar, 256Mi for the node plugin), as required by
  the repository resource-sizing policy. These memory ceilings include headroom
  over the trial observations; reassess the node plugin when adding many mounts.
- `zerofs` is a non-default RWX StorageClass with `Retain`. PVC capacity is
  descriptive: CSI does not enforce per-PVC quotas. The gateway's filesystem-wide
  `max_size_gb = 200.0` caps logical usage at 200 decimal GB (about 186.3 GiB).
- A single gateway matches the single-node cluster. Kubernetes restarts it after
  failure; filesystem access pauses during recovery. There is no gateway failover.
  Historical benchmark measurements describe the former two-gateway configuration.

CSI gateway/node images are pinned to the published v2.3.5 image digests
(source revision `4283dadfd2c6053d7d7ea04742f0d8465065f596`). Manifests were adapted
from upstream deployment examples at `a0ae1922dd198b0d9ed1cf214ec983a38e35769e`.
The node plugin uses FUSE, requires `/dev/fuse`, and has an `OnDelete` update strategy.
Restarting it breaks its active FUSE mounts until consuming pods are recreated.
Do not restart this plugin while applications depend on it.

## Measured benchmarks — 22 October 2026

Measured on the production single-node Talos cluster against OVH Mumbai using a
separate benchmark PVC and the historical `zerofs-test` backend. These results
come from the former leader/standby setup, with a 6 decimal GB disk cache and
0.5 decimal GB memory cache per gateway. The current standalone gateway has not
been benchmarked with the full arr workload.

Fio used direct I/O, synchronous workers at queue depth one, a **32 MiB/s aggregate
traffic cap**, and a 500m CPU limit per gateway. Four-reader runs capped each
worker at 8 MiB/s. Sequential results near 32 MiB/s reached the configured cap;
they do not measure maximum throughput. The current gateway CPU is uncapped.

| File size | Workload | Throughput (MiB/s) | p95 completion latency (ms) |
| --- | --- | ---: | ---: |
| 2 GiB | Sequential write | 30.92 | 77.07 |
| 2 GiB | CRC32C verification read | 32.01 | 18.74 |
| 2 GiB | 128 KiB random read, 1 worker | 32.00 | 5.14 |
| 8 GiB | Sequential write | 31.72 | 78.12 |
| 8 GiB | Sequential read | 32.00 | 15.53 |
| 8 GiB | CRC32C verification read | 32.00 | 16.06 |
| 8 GiB | 128 KiB random read, 1 worker | 2.85 | 152.04 |
| 8 GiB | 128 KiB random read, 4 workers (aggregate throughput) | 15.55 | 107.48 |
| 8 GiB | Sequential 1 GiB range, first pass | 31.84 | 29.75 |
| 8 GiB | Sequential 1 GiB range, repeat | 32.03 | 21.10 |

All listed fio runs completed with error code zero. CRC32C verification passed;
separate arr-style checks passed hardlink creation, rename, matching inode
numbers, link count two, and matching sampled bytes for both file sizes. Gateway
memory during writes was approximately 1.0–1.4 GiB. No gateway or CSI restart
occurred during successful runs; Emby retained its pod identity and restart count.

The 2 GiB file fits in cache; the 8 GiB file exceeds the disk cache and exercises
eviction and backend reads. These were not strictly cold-cache runs: direct I/O
bypasses the client page cache, while ZeroFS caches remain active. The repeated
1 GiB range fits in cache. Cache contents also differed between random-read
passes, so the four-worker improvement is not a controlled concurrency comparison.

No 20 GiB run, actual qBittorrent swarm, sustained 48 MiB/s download, concurrent
Emby playback/seeding, or gateway failover was measured. The results establish
capped sequential throughput and filesystem correctness for this trial, not a
guarantee for those workloads. The original report and raw fio JSON remain in Git
history at commit `e784869`, under `benchmark/results/` in this directory.

## Deployment and operation

Flux manages the CSI driver, standalone gateway, cache claim, non-default
StorageClass and encrypted credentials through `zerofs/ks.yaml`. The cache claim
is a native StatefulSet claim without VolSync. The shared arr-stack base adds a
media PVC in each cluster and mounts it into qBittorrent, Sonarr and Radarr. Keep
application configuration and SQLite databases on local storage. Follow the
[arr-stack setup](../../../../apps/base/arr-stack/README.md) before selecting
ZeroFS download paths.

The gateway restricts ingress with NetworkPolicy: 9P from the CSI node plugin and
admin RPC from the CSI controller. There is no replication listener or public route.

The one-time benchmark manifests, scripts and raw results were removed from the
current tree; the measurements are summarized above. Its
production PVCs, PV objects and obsolete `zerofs-test` StorageClass were deleted
before switching to the permanent backend; historical S3 data remains. Removing
Kubernetes objects does not remove that data or stop storage charges. Existing
volumes do not migrate when a gateway's backend changes.

Never delete cache files from a running gateway or remove internal S3 objects
manually from an active ZeroFS filesystem. Ordinary restarts reuse the current
filesystem's cache; no custom startup cleanup runs.

References: https://www.zerofs.net/docs/kubernetes-csi,
https://www.zerofs.net/docs/caching, https://www.zerofs.net/docs/configuration.

## Adding another cluster

Reuse the shared controller base and arr-stack base. In the new controller
overlay, patch the `zerofs` Flux Kustomization's
`spec.postBuild.substitute.ZEROFS_STORAGE_URL` to a unique S3 prefix, for example
`s3://rizexor-media/zerofs-staging`. Copy the small prod/dev overlay patch, changing
only that URL. Never share a prefix between independent cluster writers. The
gateway receives this one value; do not add a second backend setting or rollout
annotation.

Provision the cluster's SOPS decryption access, ZeroFS storage credentials and
persistent encryption password. A shared encrypted Secret is currently used;
use a cluster-specific Secret override if credentials or passwords must differ.
Verify access to the chosen bucket/prefix and preserve the password needed to
reopen that filesystem.

Before enabling reconciliation, check scheduler capacity for the gateway's 250m
CPU and 2Gi memory requests plus the CSI pods. Check actual TopoLVM thin-pool free
space for an 8Gi cache and future growth, rather than only PVC sizes. Dev is
currently unused; its live capacity has not been verified. Each cluster has its
own cache PVC and 200 GB filesystem quota.

CSI node/controller pods currently use pod networking. The gateway NetworkPolicy
selects those pods; reassess network access before introducing `hostNetwork`.
The three arr Flux Kustomizations explicitly check their HelmReleases despite
`wait: false`, so their Ready condition includes Helm release health.

After rollout, follow the shared arr-stack README to create directories, verify
hardlinks and configure per-item opt-in. New clusters need the same setup; Flux
provides the PVC and mounts, not application root folders or download categories.
