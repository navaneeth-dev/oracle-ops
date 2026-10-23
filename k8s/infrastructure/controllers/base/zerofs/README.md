# ZeroFS CSI storage

Shared infrastructure, included by both production and dev controller overlays.
The temporary benchmark is deliberately **not** a Flux resource. The opt-in arr
integration is documented in [arr-zerofs](../../../../apps/base/arr-zerofs/README.md).
Emby is unchanged; do not drain/reboot the node or restart Emby for storage checks.

## Storage and resource budget

- Backends: production `s3://rizexor-media/zerofs`, dev
  `s3://rizexor-media/zerofs-dev`, OVH Mumbai (`ap-south-mum`). The dev overlay
  overrides the backend ConfigMap key and rollout annotation. The gateway reads
  the selected backend setting. Historical
  benchmarks used the separate `zerofs-test` prefix, retained without migration. This is
  ZeroFS's internal object format, separate from existing media object keys.
- `secret-ovh.yaml` reuses the endpoint/access key/secret key from Sonarr's disabled
  upload integration, encrypted with the repository's SOPS recipient. It has a
  separate generated ZeroFS password. Keep that encrypted password to reopen data.
  Sonarr's upload hook and Discord webhook are not enabled or copied.
- One standalone gateway with an **8 GiB TopoLVM cache PVC**, **6 decimal GB disk cache**,
  and **0.5 decimal GB memory cache**. No VolSync or backup component is used.
- The cache budget includes metadata and file data. A 20 GiB file need not fit
  locally. Reads outside cache fetch object data from OVH.
- Initial physical thin-pool measurement: 160,897,695,744 bytes, 75.77% used,
  approximately 36.3 GiB free. Filling one 8 GiB claim leaves about 28.3 GiB
  of physical headroom, before other workloads grow. Thin PVC capacity is not
  a measurement of physical free space.
- Gateway CPU request: 250m; CPU limit: 500m. Memory request and
  limit: 2Gi, based on observed usage around 1.0–1.4 GiB plus headroom. These are bounded **trial values**, not upstream sizing
  recommendations. Check throttling and memory before selecting production values.
  The manual benchmark used temporary 25m gateway requests to fit the current
  scheduler budget; limits remained 500m/2Gi. Roll out the preceding CPU-sizing
  commit before reconciling these 250m requests through GitOps. CSI memory requests
  equal limits (64Mi per small sidecar, 256Mi for the node plugin), as required by
  the repository resource-sizing policy. These memory ceilings include headroom
  over the trial observations; reassess the node plugin when adding many mounts.
- `zerofs` is a non-default RWX StorageClass with `Retain`. PVC capacity is
  descriptive: CSI does not enforce per-PVC quotas. The gateway's filesystem-wide
  `max_size_gb = 200.0` caps logical usage at 200 decimal GB (about 186.3 GiB).
- A single gateway matches the single-node cluster. Kubernetes restarts it after
  failure; filesystem access pauses during recovery. There is no gateway failover.
  The original benchmark results describe the former two-gateway configuration.

CSI gateway/node images are pinned to the published v2.3.5 image digests
(source revision `4283dadfd2c6053d7d7ea04742f0d8465065f596`). Manifests were adapted
from upstream deployment examples at `a0ae1922dd198b0d9ed1cf214ec983a38e35769e`.
The node plugin uses FUSE, requires `/dev/fuse`, and has an `OnDelete` update strategy.
Restarting it breaks its active FUSE mounts until consuming pods are recreated.
Do not restart this plugin while applications depend on it.

## Apply locally before a GitOps push

Run from `clusters/prod`, using the production mise environment. This does not
require committing or pushing. The namespace must exist before applying Secrets.
The manual infrastructure overlay uses temporary 25m gateway CPU reservations;
Flux uses the 250m requests in `app/` after the CPU-sizing rollout. The filter
prevents the encrypted SOPS document from being applied as credentials.

```sh
zerofs_dir=../../k8s/infrastructure/controllers/base/zerofs
mise exec -- kubectl create namespace zerofs --dry-run=client -o yaml | mise exec -- kubectl apply -f -
mise exec -- sops decrypt "$zerofs_dir/app/secret-ovh.yaml" | mise exec -- kubectl apply -f -
mise exec -- kubectl kustomize "$zerofs_dir/benchmark/infra" | mise exec -- yq 'select(.kind != "Secret" or .metadata.name != "zerofs-ovh")' | mise exec -- kubectl apply -f -
mise exec -- kubectl apply -k "$zerofs_dir/benchmark"
mise exec -- kubectl rollout status -n zerofs deployment/zerofs-benchmark --timeout=120s
```

The gateway restricts ingress with NetworkPolicy: 9P from the CSI node plugin and
admin RPC from the CSI controller. There is no replication listener or public route.

## Temporary fio benchmark

The pod is idle until explicitly invoked. It has a fio container and a Python
container for arr-style hardlink checks, both using the same test PVC. Tool images
are pinned; the current arm64 fio binary is 3.23 (the image's amd64 binary differs).
CPU limits are 500m per benchmark container; memory requests equal limits
(64Mi for Python, 256Mi for fio). The fio script defaults to one job (four for `parallel`), queue
depth one per job, `psync`, direct I/O, incompressible buffers, CRC32C verification headers,
and a **32 MiB/s traffic limit**. `--max-jobs=1` also bounds fio startup allocation (eight slots for the four-reader mode).
Results under that limit are not a measurement of maximum throughput.

```sh
# Initial smoke test: 2 GiB fits inside the file-data cache.
mise exec -- kubectl exec -n zerofs deploy/zerofs-benchmark -c fio -- sh /scripts/fio.sh write 2
mise exec -- kubectl exec -n zerofs deploy/zerofs-benchmark -c fio -- sh /scripts/fio.sh verify 2
mise exec -- kubectl exec -n zerofs deploy/zerofs-benchmark -c benchmark -- python /scripts/benchmark.py --gib 2

# Larger sequential file: 8 GiB exceeds one gateway's entire disk cache.
mise exec -- kubectl exec -n zerofs deploy/zerofs-benchmark -c fio -- sh /scripts/fio.sh write 8
mise exec -- kubectl exec -n zerofs deploy/zerofs-benchmark -c fio -- sh /scripts/fio.sh read 8
mise exec -- kubectl exec -n zerofs deploy/zerofs-benchmark -c fio -- sh /scripts/fio.sh verify 8

# 128 KiB random reads for 60 seconds, then repeat a 1 GiB sequential range.
mise exec -- kubectl exec -n zerofs deploy/zerofs-benchmark -c fio -- sh /scripts/fio.sh random 8
mise exec -- kubectl exec -n zerofs deploy/zerofs-benchmark -c fio -- sh /scripts/fio.sh parallel 8
mise exec -- kubectl exec -n zerofs deploy/zerofs-benchmark -c fio -- sh /scripts/fio.sh warm 8
mise exec -- kubectl exec -n zerofs deploy/zerofs-benchmark -c fio -- sh /scripts/fio.sh warm 8
```

`write 20` / `read 20` / `verify 20` are available for a later larger run.
Write refuses to overwrite an existing test file; read/verify modes cannot create
files. All writes stay in `/data/fio` on the dedicated ZeroFS test volume.
Record fio JSON, p95/p99 completion latency, CPU usage/throttling, memory, cache
PVC usage, thin-pool usage, and object-store request/traffic costs.

Direct I/O bypasses the client page cache, **not** ZeroFS's memory/disk caches.
Writes populate ZeroFS cache, so the first read is not automatically a cold read.
The 8/20 GiB full-file passes exercise eviction and backend reads; repeated 1 GiB
range reads test warm cache. A strictly cold test needs a controlled cache reset
with only these test clients stopped; never delete cache files from a live gateway
or drop the node's caches while Emby is running. Random reads approximate piece
access, not a complete torrent workload or a guarantee of seeding throughput.
The `parallel` mode uses four readers with an 8 MiB/s cap each, keeping the total
cap at 32 MiB/s while checking whether concurrent requests can hide backend latency.

Delete the benchmark Deployment after the experiment to release its CPU requests.
The test PVC/PV and object data are retained intentionally. Removing a pod does
not remove the OVH data or stop storage charges. Delete only trial files through
the mounted filesystem when finished; never remove internal S3 objects manually
from an active ZeroFS volume.

## End goal: GitOps

Push only when ready. Flux will manage the CSI driver, standalone gateway, cache claim,
non-default StorageClass, and encrypted credentials through `zerofs/ks.yaml`.
The cache claim is a native StatefulSet claim, without VolSync. Temporary test
pods remain manual. The production arr overlay adds a shared media PVC and mounts
it into qBittorrent, Sonarr and Radarr. Keep app config/SQLite databases on local
storage and run the direct setup/hardlink check documented in arr-zerofs before
changing any production download paths.

References: https://www.zerofs.net/docs/kubernetes-csi,
https://www.zerofs.net/docs/caching, https://www.zerofs.net/docs/configuration.

## Retiring the previously applied standby

This commit changes the desired configuration only. The former gateway was applied
manually and `zerofs/ks.yaml` has `prune: false`; removing it from YAML does not stop
that live pod. During a deliberate rollout:

1. Confirm no workloads are currently using ZeroFS mounts. Keep Emby and the node
   untouched. Existing arr apps have not yet been mounted on this filesystem.
2. Scale `zerofs-gateway-b` to zero before restarting the retained leader. Do not
   leave the old HA-configured standby running against a standalone leader.
3. Apply the retained leader configuration and single-endpoint admin Secret. The
   readiness probe now checks 9P, since port 9000 is no longer used.
4. StorageClass parameters are immutable. Apply the new permanent `zerofs`
   StorageClass from this commit; it has only the retained gateway. Do not try
   to patch the previously applied class in place. Existing PV volumeAttributes also retain
   their old endpoint list and are not rewritten by a new StorageClass.
5. Validate mounts and recheck data before deleting the retired StatefulSet,
   Service, ConfigMap, and finally `cache-zerofs-gateway-b-0`. Only that cache PVC
   is disposable; preserve the leader cache, data PVC/PV, encryption Secret, and
   object-store data. Until the old cache claim is deleted, its local disk space
   remains allocated. No arr data migration or object-prefix rename is included
   in this topology change.

The manual benchmark now uses a fresh `zerofs-benchmark-data` claim on `zerofs`.
The previous benchmark claim and its historical data are retained; changing the
StorageClass field of an already bound PVC is not supported.
