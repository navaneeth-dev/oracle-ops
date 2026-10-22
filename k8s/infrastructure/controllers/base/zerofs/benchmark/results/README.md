# ZeroFS trial results — 22 October 2026

Measured on the production single-node Talos cluster against OVH Mumbai, using only
the dedicated ZeroFS test PVC. Live Emby and arr workloads were not modified for the trial.

Fio runs use direct I/O, synchronous workers at depth one, a 32 MiB/s aggregate cap,
and 500m CPU limits on each gateway. Throughput at that cap is a lower bound on
capacity under this configuration, not a maximum-throughput benchmark.

| File | Workload | MiB/s | p95 completion latency (ms) | Duration (s) |
|---|---|---:|---:|---:|
| 2 GiB | write | 30.92 | 77.07 | 66.229 |
| 2 GiB | CRC32C verification | 32.01 | 18.74 | 63.975 |
| 2 GiB | 128 KiB random read, 1 worker | 32.00 | 5.14 | 60.001 |
| 8 GiB | write | 31.72 | 78.12 | 258.257 |
| 8 GiB | read | 32.00 | 15.53 | 255.975 |
| 8 GiB | CRC32C verification | 32.00 | 16.06 | 255.975 |
| 8 GiB | 128 KiB random read, 1 worker | 2.85 | 152.04 | 60.004 |
| 8 GiB | 128 KiB random read, 4 workers | 15.55 | 107.48 | 60.090 |
| 8 GiB | 1 GiB range, first pass | 31.84 | 29.75 | 32.160 |
| 8 GiB | 1 GiB range, repeat | 32.03 | 21.10 | 31.975 |

CRC verification rows have fio error code zero. The separate arr-style check
passed hardlink creation, rename, inode identity, link count two, and matching
sample bytes for both the 2 GiB and 8 GiB files.

The 2 GiB data fits in cache. The 8 GiB file exceeds the 6 GB total cache budget
(approximately 4.9 GB is available to raw file/object parts). The sequential full-file
passes exercise cache eviction and object reads; these were not strictly cold-cache
runs. Repeated 1 GiB range reads fit in cache. A 20 GiB workload is scripted but was
not run in this trial. The four-worker random test explores concurrency but does not measure the
aggregate throughput of multiple concurrent torrent peers.

Initial fio startup exceeded the 256Mi container limit with its default maximum-job
allocation. Limiting fio to `--max-jobs=1` fixed startup; successful rows above use
that setting. No gateway or CSI restart occurred during the successful benchmark
runs. Gateway memory observed during writes was approximately 1.0–1.4 GiB, within
the 2Gi limit per gateway.

The existing Emby pod retained its identity and its pre-existing restart count of
one. No node drain, reboot, Emby rollout, or arr storage change was performed.

Raw fio JSON is retained alongside this report. CPU-sizing changes are documented
separately in `docs/cpu-sizing/2026-10-22/` and were not deployed for this test.


The four-reader test increased aggregate random-read throughput compared with the
single-reader test, while retaining high per-request latency. Cache contents differ
between passes, so the ratio is not a controlled measurement of concurrency alone.
There was no actual qBittorrent swarm test, no 20 GiB run, and no gateway failover
test. Keep production arr storage unchanged until those workload-specific checks
are justified by these results.

`resources.csv` contains 30-second CPU/memory/pool observations starting during
the first 8 GiB read. The active gateway was throttled in approximately 7% of CPU
periods in an early sampled read interval. Existing node CPU bursts can still
compete with this workload; the 0.5-core limit deliberately bounds this trial.

After collecting the results, the temporary benchmark Deployment and generated
benchmark ConfigMaps were removed. The test PVC/data and manually applied CSI and
gateways were retained. The committed GitOps defaults reserve 250m CPU and 2Gi
memory per gateway; the original live trial used 25m CPU and 768Mi memory requests,
with the same 500m CPU / 2Gi memory limits. The committed memory requests equal
limits throughout. CSI plugin/sidecar memory limits were sized from observed use
plus headroom for the prepared manifests; those revised limits were server-dry-run
validated, not rolled out as part of the measured trial.
