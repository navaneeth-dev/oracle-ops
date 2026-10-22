# Production CPU sizing — 22 October 2026

Prepared locally only. No rollout, live resource edits, or Emby changes.

## Evidence and result

Window: **15–22 October 2026, 17:30 UTC (23:00 IST)**. VictoriaMetrics
provided seven days of history, including replaced pods. Node allocatable CPU
is **3,950m**. Node non-idle CPU averaged **714m** (17.9% of four node CPU
cores), p95 **807m**, and maximum five-minute rate **3,693m**. Low average
utilization therefore does not mean the node never becomes busy.

Excluding ZeroFS, simultaneous workload CPU averaged **529m**, p95 **626m**.
Historical container CPU requests averaged **3,367m**, and the final sample
was **3,466m** (87.7% of allocatable). The difference between node and container
usage includes host/control-plane services. Node totals include the final few
minutes of ZeroFS trials; workload sizing excludes the entire ZeroFS namespace.

The prepared changes save **1,101m** of steady-state requests. Applied to the
final snapshot, requests become **2,365m** (59.9%), leaving **1,585m** of
scheduler headroom instead of 484m. These are estimates for the same replica
counts, excluding ZeroFS and temporary rollout surge pods; they are not a
promise of unused CPU or a reduction in actual CPU consumption.

## Prepared manifest changes

All CPU values below are millicores. p95/p99 use five-minute usage rates;
peak uses one-minute rates sampled every minute. Requests are scheduling
reservations and contention weights; workloads can exceed them while CPU is
available. Small services get a 10–25m floor rather than their tiny idle p99.
Existing memory settings and CPU limits are preserved except for LibreSpeed.

| Workload/container | Request before → after | p95 / p99 | Peak 1m | Reason |
|---|---:|---:|---:|---|
| KRO | 256 → 20 | 1.18 / 1.21 | 1.62 | 20m is over 16× p99; keep 1-core limit |
| Flux helm-controller | 100 → 50 | 3.56 / 6.94 | 157.84 | Reconciliation bursts; retain substantial headroom |
| Flux kustomize-controller | 100 → 50 | 8.77 / 21.04 | 167.86 | Over 2× p99; preserve burst allowance |
| Flux notification-controller | 100 → 20 | 1.08 / 1.17 | 2.36 | Large idle reservation |
| Flux source-controller | 50 → 20 | 1.89 / 2.92 | 17.09 | Above observed peak and p99 |
| vmagent | 200 → 100 | 29.53 / 31.01 | 117.32 | Over 3× p99; no CPU cap; 5m peak 127.75m |
| Grafana | 100 → 25 | 15.06 / 15.29 | 60.88 | Above p99; allow dashboard bursts |
| VolSync controller | 100 → 20 | 1.08 / 1.16 | 23.66 | Controller only; backup mover jobs unaffected |
| Audiobookshelf | 50 → 10 | 0.69 / 0.73 | 1.95 | Above observed peak |
| Prowlarr | 50 → 20 | 3.01 / 3.48 | 14.05 | Above observed peak |
| qBittorrent app | 100 → 50 | 2.81 / 3.50 | 546.40 | Keep room for torrent bursts; no CPU cap |
| Radarr | 50 → 25 | 4.31 / 4.59 | 232.62 | Over 5× p99; allow scans to burst |
| Recyclarr | 100 → 10 | 0.02 / 0.02 | 71.16 | Mostly idle, intermittent scheduled work; no CPU cap |
| SABnzbd | 100 → 25 | 1.25 / 1.36 | 2.47 | Quiet historical week; burst remains uncapped |
| Sonarr | 100 → 50 | 3.43 / 7.06 | 153.45 | Conservative floor for scans/imports; no CPU cap |
| LibreSpeed | 50 → 10 | 0.14 / 0.15 | 9.05 | Explicit request replaces request inherited from CPU limit |

LibreSpeed's **50m CPU limit is removed**. Weighted throttled-period ratio was
0.124% over the week but reached **36.10%** in a five-minute sample. Even with
low smoothed CPU usage, quota can constrain short bursts. A speed-test service
should be able to burst; a larger arbitrary cap would still constrain tests.
This does not establish how much latency or bandwidth was lost. Run a controlled
speed test after rollout and check node contention, especially during playback.

## Limits and reservations retained or deferred

- **Emby: untouched**, including its manifest. Only 73.9% of the week has Emby
  history (the earlier portion has Jellyfin). Emby reached 3,262m on a one-minute
  rate and 2,976m on a five-minute rate despite low p99. Keep its 100m request
  and uncapped CPU; idle history does not represent transcoding demand.
- **VictoriaMetrics single:** 150m request, 1,200m limit; p99 63m and 1m peak
  1,128m. Weighted throttling below 0.001%, max 0.044%; no evidence for a limit
  increase. Do not cap it at a multiple of idle p99.
- **Flux:** keep 1-core limits. Helm/kustomize weighted throttling is 0.335% /
  1.165%; worst five-minute ratios 9.07% / 27.45%. These reveal burst pressure,
  but weekly CPU and throttling alone do not prove a sustained inadequate cap.
  Check reconciliation duration/errors before removing these limits.
- **KubeVela core:** 500m cap, p99 13.38m, peak 122.60m; weighted throttling
  0.595%, worst 23.15%. Investigate reconcile latency and consider an uncapped
  controller if delays correlate. Its installation source is absent here.
- **vmalert / alertmanager:** caps 200m / 100m, p99 5.50m / 0.58m; weighted
  throttling 0.001% / 0.024%. Retain; no sustained limit problem established.
- **dev/test:** reserves and caps 500m with CPU rounded to 0.00m for the entire
  week. Largest remaining obvious excess: propose 10m request while retaining
  its 500m cap (490m further saving), or retire it if unused. It is generated
  by KubeVela and has no corresponding Application manifest in this repository;
  change its owning source rather than patching the Deployment live.
- **CoreDNS:** two replicas reserve 200m combined; combined p99 7.02m and peak
  13.01m. Consider 25m per replica (150m saving). **metrics-server:** 100m versus
  p99 2.99m and peak 5.04m; consider 25m (75m saving). Both require changes to
  their Talos-managed installation source, outside this manifest change.
- **Envoy:** gateway reserves 100m versus p99 1.78m; proxy reserves 100m versus
  p99 10.78m (peak 52.90m). Further candidates are 25m gateway / 50m proxy;
  retain for now to validate traffic and connection bursts separately.
- **Unreserved services also matter:** Authentik worker/server/Postgres p99 is
  85m / 36m / 163m, and Cilium p99 is 44m. Their absent requests offer no CPU
  share guarantee under contention. Follow up with approximately 100m / 50m /
  200m / 75m reservations, respectively, before using all freed scheduling room.
- **Qui (1% coverage), ZeroFS and benchmarks:** insufficient history, no sizing
  changes. Jellyfin is historical, not a current rollout candidate. Homepage,
  Bazarr, and the remaining low-resource controllers are retained.

## Method and reproducibility

[workloads.csv](workloads.csv) contains all observed workload/container summaries,
including coverage and historical request/limit ranges. Missing throttling
means no CFS quota series was present, **not measured zero throttling**. Missing
request/limit entries mean no corresponding CPU resource metric was returned.
Historical min/max requests aggregate concurrent replicas; rollout overlap can
increase them without a configuration change. The snapshot at collection time
was used for the before/after savings above.

[queries.json](queries.json) records exact queries, timestamps and evaluation
steps. Access used the production context from `clusters/prod` via `mise exec`:

```sh
mise exec -- kubectl port-forward -n observability svc/vmsingle-stack 18428:8428
# GET http://127.0.0.1:18428/api/v1/query_range
# query=<queries.json expression>&start=<start>&end=<end>&step=300 (peak1m: 60)
```

CPU usage is filtered to `metrics_path="/metrics/cadvisor"`: the resource
endpoint exports the same counters and summing both would double-count CPU.
Rates sum by namespace/pod/container, then simultaneous pods are combined by
controller and container before computing percentiles. Deployment hashes and
pod suffixes are matched across replacements; stateful/daemon workloads use
current owner names. Coverage is populated five-minute evaluation points out
of 2,017. Throttling is sum of throttled-period rates divided by sum of total
period rates over the window; maximum/p95 use pointwise five-minute ratios.
Counter rates are sampled estimates, not instantaneous maxima. Raw responses
were used during analysis; the compact summaries preserve the reviewed result.

## Validation and remaining rollout

Validation: Kustomize builds for production apps, controller base, Grafana app,
and production Flux; Helm renders of each changed HelmRelease using its pinned
chart, compared before/after to ensure only CPU resources change and inherited
memory/default limits survive. No server-side apply or rollout was performed.

After user approval, publish/reconcile through the usual GitOps path. These
changes replace pods and can briefly interrupt single-replica services;
Grafana uses Recreate. Roll out infrastructure and apps in small batches,
watch readiness, Flux reconciliation, CPU pressure, and application latency.
Avoid scheduling new load against the entire freed request budget. Exercise
LibreSpeed, imports/downloads, backups and Grafana; inspect throttling and CPU
for 24–48 hours and review another full week. Increase a request if contention
causes latency; restore the prior request if necessary. SABnzbd's quiet week
is not evidence of download/unpack capacity. Emby must remain untouched during
all rollout steps; do not restart, edit, or reconcile changes to its release.
Local commits alone do not deploy anything; nothing has been pushed.
