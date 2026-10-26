# Storage benchmark

## HostDZire India StorageVPS #2 — October 26, 2026

**Initial local result:** all ten fio jobs completed with `error=0`. The later
32 GiB pass had lower random-read rates than the initial 4 GiB pass, but the
follow-up below shows that test order/backend state confounds attributing this
solely to working-set size. These local measurements do not establish
NFS/WAN performance or performance under concurrent torrent/playback load.

### Environment

- Plan: 2 vCPU, 3 GB RAM, 1 TB SATA RAID60, advertised 1 Gbit/s port,
  2 TB/month traffic counting both directions, €29/year.
- Observed: 2 Intel Xeon Platinum 8269CY virtual CPUs, 2.9 GiB RAM, no swap;
  VMware hypervisor.
- Ubuntu 26.04.1 LTS, kernel `7.0.0-38-generic`, fio `3.41`.
- Guest disk: 1,000 GiB virtual `sda`, rotational flag set; ext4 root filesystem
  reporting 969 GiB total and 967 GiB available before testing. The guest cannot
  verify the provider's physical disk type or RAID layout.
- Test window: 17:52–17:58 UTC (23:22–23:28 Asia/Calcutta).
- fio was installed for this test. No storage services or cluster resources
  were configured or changed.

### Matching Vultr baseline: 4 GiB working set

The five workloads match the earlier Vultr **local disk** suite: `libaio`,
`direct=1`, one shared file, and group reporting. Sequential jobs transfer
4 GiB once; random 128 KiB jobs run for 30 seconds and random 4 KiB for
20 seconds. Queue depth is per worker. Four workers read the same file.

| Workload | Workers × queue depth | MiB/s | IOPS | Mean completion latency (ms) | p99 completion latency (ms) |
| --- | --- | ---: | ---: | ---: | ---: |
| Sequential write, 1 MiB | 1 × 8 | 2,696.51 | 2,696.51 | 2.790 | 5.669 |
| Sequential read, 1 MiB | 1 × 8 | 857.98 | 857.98 | 9.138 | 212.861 |
| Random read, 128 KiB | 1 × 1 | 68.78 | 550.24 | 1.775 | 17.170 |
| Random read, 128 KiB | 4 × 1 | 298.13 | 2,385.02 | 1.649 | 15.139 |
| Random read, 4 KiB | 1 × 32 | 52.62 | 13,469.52 | 2.366 | 32.899 |

### Larger working set: 32 GiB

A fresh file was written before these reads. Sequential jobs transfer 32 GiB
once; each random job runs for 60 seconds. The write additionally uses
`end_fsync=1` and `refill_buffers=1`, so it is not an exact parameter-for-parameter
comparison with the 4 GiB write. All other workload settings are unchanged.

| Workload | Workers × queue depth | MiB/s | IOPS | Mean completion latency (ms) | p99 completion latency (ms) |
| --- | --- | ---: | ---: | ---: | ---: |
| Sequential write, 1 MiB | 1 × 8 | 1,452.48 | 1,452.48 | 5.263 | 13.697 |
| Sequential read, 1 MiB | 1 × 8 | 1,079.99 | 1,079.99 | 7.284 | 31.850 |
| Random read, 128 KiB | 1 × 1 | 17.13 | 137.08 | 7.186 | 26.345 |
| Random read, 128 KiB | 4 × 1 | 73.69 | 589.55 | 6.735 | 28.705 |
| Random read, 4 KiB | 1 × 32 | 14.10 | 3,608.68 | 8.857 | 42.205 |

### Interpretation and limits

- The 4 GiB write completed in 1.519 seconds. Even the 32 GiB write completed
  in 22.560 seconds. Do not treat these short, very high virtual-disk rates as
  sustained physical HDD performance or proof of durable-media throughput.
- `direct=1` bypasses the guest page cache, not hypervisor, RAID controller, or
  storage-server caches. No host-side cache flush was possible. Even 32 GiB
  may fit in a provider cache; the cause of the high sequential rates is not
  established. Reads follow writes, so these are not proven cold-media reads.
- The later larger-working-set pass had roughly fourfold lower 128 KiB
  random-read rates: 68.78 → 17.13 MiB/s for one worker, 298.13 → 73.69 MiB/s
  for four. The follow-up below shows this is not a controlled measurement
  of working-set size alone; these shared-storage results vary with time/order.
- The earlier Vultr local NVMe baseline was 2,385.6 MiB/s sequential write,
  3,387.9 MiB/s sequential read, 877.7/2,854.6 MiB/s random 128 KiB read with
  one/four workers, and 80,151 random 4 KiB read IOPS. This HostDZire VPS is
  materially slower for random reads; Vultr's NFS/playback results cannot be
  assumed to apply to it.
- The observed local read rates exceed the earlier approximately 3 MiB/s
  direct-play workload, but that alone does not prove reliable playback under
  torrent writes, multiple streams, contention from other tenants, or WAN latency.
- These are single samples, not a sustained-load, data-integrity, or durability
  qualification. Random writes and mixed read/write workloads were not measured.
- All test files and their temporary directories were removed. A separate
  post-cleanup SSH check found no fio processes or benchmark directories and
  confirmed filesystem use had returned to 2.6 GiB, with 967 GiB available.

### Follow-up: why are sequential reads so fast?

A separate [high-dial investigation](https://ampcode.com/threads/T-01a17961-803c-7727-bd7a-09add1554458)
completed eight additional local jobs without errors, ending at 18:11 UTC.
It fully wrote a 128 GiB regular file before reading it, using `libaio`,
`direct=1`, 1 MiB blocks, and queue depth 8:

| Workload | MiB/s | Duration (seconds) |
| --- | ---: | ---: |
| Full 128 GiB write | 1,750.33 | 74.884 |
| First full 128 GiB read | 1,860.95 | 70.433 |
| Repeat full 128 GiB read | 1,869.71 | 70.103 |
| Sequential 16 GiB read, queue depth 1 | 1,486.62 | — |

Guest disk counters recorded approximately 128 GiB per full read while guest
`Cached` stayed around 0.75 GiB. Seven data samples compressed to 94–100% of
their original size, inconsistent with a zero-filled/sparse-file explanation.
The sequential reads did not collapse as a short burst was exhausted: their
last-ten-second averages were approximately 1,939/1,942 MiB/s, versus
1,666/1,833 MiB/s in the first ten seconds.

Random 128 KiB reads at queue depth 1 for 30 seconds yielded 24.41, 20.03,
and 15.49 MiB/s over 4, 32, and 128 GiB ranges. Repeating the 4 GiB range
after the larger reads yielded 18.81 MiB/s, showing that ordering/backend
state also matters. The 128 GiB random-read median completion latency was
6.717 ms.

**Conclusion:** the high sequential rate is not merely a tiny-file/guest-RAM
artifact. SATA RAID60 describes an array, not a single SATA link: aggregate
streaming bandwidth can exceed single-drive bandwidth. Fast array streaming
and backend read-ahead/cache are consistent with these results, alongside much
slower seek-heavy random access. The physical disk count, RAID/cache topology,
genuinely cold-media rate, and long-term tenant contention remain unverified;
provider confirmation would be needed to distinguish their contributions.
The 1 Gbit/s network port still limits theoretical line-rate transfer to
approximately 119 MiB/s before protocol overhead, regardless of local disk speed.
The disposable file was removed and only commands/results crossed the WAN.

### Reproduce

Run only on an otherwise idle VPS. This creates a temporary regular file on
the root filesystem, never writes directly to a block device, and deletes the
file on exit. Allow at least 33 GiB free. Install fio first if necessary.

```bash
set -euo pipefail
dir=$(mktemp -d /root/hostdzire-fio.XXXXXX)
trap 'rm -f "$dir/fiotest"; rmdir "$dir"' EXIT
run() {
  local name=$1
  shift
  fio --name="$name" --directory="$dir" --filename=fiotest --size=4G \
    --ioengine=libaio --direct=1 --group_reporting --output-format=json "$@"
}
run seq-write --rw=write --bs=1M --iodepth=8
run seq-read --rw=read --bs=1M --iodepth=8
run rand128k-1 --rw=randread --bs=128k --iodepth=1 --numjobs=1 --runtime=30 --time_based
run rand128k-4 --rw=randread --bs=128k --iodepth=1 --numjobs=4 --runtime=30 --time_based
run rand4k --rw=randread --bs=4k --iodepth=32 --runtime=20 --time_based
rm "$dir/fiotest"
run large-seq-write --size=32G --rw=write --bs=1M --iodepth=8 --end_fsync=1 --refill_buffers=1
run large-seq-read --size=32G --rw=read --bs=1M --iodepth=8
run large-rand128k-1 --size=32G --rw=randread --bs=128k --iodepth=1 --numjobs=1 --runtime=60 --time_based
run large-rand128k-4 --size=32G --rw=randread --bs=128k --iodepth=1 --numjobs=4 --runtime=60 --time_based
run large-rand4k --size=32G --rw=randread --bs=4k --iodepth=32 --runtime=60 --time_based
```

## Oracle → HostDZire NFS — October 26, 2026

Measured from a disposable pod on the production Talos node, UID/GID 1000,
through the permanent `hostdzire` PV/PVC. Oracle's NFS client address was
`100.92.137.3`; the server was `100.125.227.18:/srv/nfs-data/oracle`. Tailscale
reported a direct connection with a 21 ms ping sample. Mounted NFSv4.2 with
`hard,noatime`, negotiated 512 KiB read/write sizes. fio was version 3.39.

The five direct-I/O workloads match the earlier Vultr **NFS** suite: one
4 GiB file, `libaio`, `direct=1`, group reporting, 20 seconds per random
128 KiB job, and 15 seconds for random 4 KiB. Sequential jobs transfer the
file once. Queue depth is per worker. All five completed with `error=0`.

| Workload | Workers × queue depth | MiB/s | IOPS | Mean completion latency (ms) | p99 completion latency (ms) |
| --- | --- | ---: | ---: | ---: | ---: |
| Sequential write, 1 MiB | 1 × 8 | 27.95 | 27.95 | 285.993 | 3,238.003 |
| Sequential read, 1 MiB | 1 × 8 | 78.47 | 78.47 | 101.743 | 158.335 |
| Random read, 128 KiB | 1 × 1 | 3.95 | 31.61 | 31.534 | 66.322 |
| Random read, 128 KiB | 4 × 1 | 17.81 | 142.51 | 27.942 | 56.361 |
| Random read, 4 KiB | 1 × 32 | 5.08 | 1,299.50 | 24.558 | 40.108 |

Hardlink validation across `torrents/` and `media/` returned the same device
and inode with link count 2, UID/GID 1000, and identical contents. The link
and source were removed afterward. This verifies filesystem support for
hardlinks, not an actual arr import.

### Buffered writes and qBittorrent's memory budget

The validation pod had memory request=limit 1 GiB, matching qBittorrent's app
container. The direct-I/O suite's cgroup peak was 99,950,592 bytes (95.3 MiB),
with no OOM events.

A subsequent **buffered** 4 GiB write (`ioengine=sync`, `direct=0`, 1 MiB
blocks, `end_fsync=1`, `refill_buffers=1`) OOMKilled the pod. Both Kubernetes
termination status and the Talos kernel's matching memory-cgroup OOM log
confirmed it. A final fsync does not prevent dirty data accumulating first.

After recreating the pod with the same 1 GiB budget, a 4 GiB synchronous
buffered write (`ioengine=sync`, `direct=0`, `sync=1`, 1 MiB blocks,
`refill_buffers=1`) completed successfully: **17.73 MiB/s**, 230.960 seconds,
zero OOM events. Peak cgroup usage reached 1,073,741,824 bytes; clean cached
pages were reclaimed at the limit. This demonstrates the difference between
fsync only at the end and opening with `O_SYNC`.

qBittorrent's installed libtorrent 2.0.15 Simple pread/pwrite backend maps
WriteThrough to Linux `O_SYNC`. Its `disk_io_write_mode` has been changed to
2 (WriteThrough) and confirmed through the API; the 1 GiB request/limit and
existing download paths are unchanged. Actual torrent block sizes and
concurrency differ from fio, so this is not a qBittorrent throughput result.
See the [HostDZire runbook](hostdzire-storage.md#memory-and-bandwidth).

The measured NFS sequential read rate has headroom over the earlier roughly
3 MiB/s Emby direct-play stream, but write-tail latency reached seconds and
single-worker random reads are latency-limited. Simultaneous download/import/
playback behavior and actual application path settings still require rollout
validation; local multi-GiB/s disk results do not imply WAN performance.

## Oracle production node — October 2025

fio results from the prod node (`/mnt/data`), October 2025.

```bash
/mnt/data/fio/examples # fio fio-seq-read.fio
file1: (g=0): rw=read, bs=(R) 256KiB-256KiB, (W) 256KiB-256KiB, (T) 256KiB-256KiB, ioengine=libaio, iodepth=16
fio-3.39
Starting 1 process
file1: Laying out IO file (1 file / 10240MiB)
Jobs: 1 (f=1): [R(1)][100.0%][r=92.0MiB/s][r=368 IOPS][eta 00m:00s]
file1: (groupid=0, jobs=1): err= 0: pid=40: Thu Oct 16 06:01:40 2025
  read: IOPS=373, BW=93.4MiB/s (97.9MB/s)(82.1GiB/900082msec)
    slat (usec): min=8, max=44943, avg=45.16, stdev=226.58
    clat (usec): min=3, max=178842, avg=42791.17, stdev=38817.15
     lat (usec): min=948, max=178885, avg=42836.34, stdev=38813.91
    clat percentiles (usec):
     |  1.00th=[  1057],  5.00th=[  1106], 10.00th=[  1139], 20.00th=[  1205],
     | 30.00th=[  1287], 40.00th=[  1450], 50.00th=[ 73925], 60.00th=[ 78119],
     | 70.00th=[ 78119], 80.00th=[ 79168], 90.00th=[ 81265], 95.00th=[ 83362],
     | 99.00th=[ 84411], 99.50th=[ 86508], 99.90th=[100140], 99.95th=[108528],
     | 99.99th=[143655]
   bw (  KiB/s): min=57115, max=140749, per=100.00%, avg=95645.33, stdev=1916.92, samples=1799
   iops        : min=  223, max=  549, avg=373.54, stdev= 7.47, samples=1799
  lat (usec)   : 4=0.01%, 10=0.02%, 50=0.01%, 100=0.01%, 250=0.01%
  lat (usec)   : 500=0.01%, 750=0.01%, 1000=0.11%
  lat (msec)   : 2=44.92%, 4=1.04%, 10=0.23%, 20=0.10%, 50=0.46%
  lat (msec)   : 100=52.99%, 250=0.11%
  cpu          : usr=0.31%, sys=1.93%, ctx=335651, majf=0, minf=1032
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=100.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.1%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=336155,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=16

Run status group 0 (all jobs):
   READ: bw=93.4MiB/s (97.9MB/s), 93.4MiB/s-93.4MiB/s (97.9MB/s-97.9MB/s), io=82.1GiB (88.1GB), run=900082-900082msec
```

```bash
/mnt/data/fio/examples # fio fio-rand-write.fio
file1: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=16
...
fio-3.39
Starting 4 processes
file1: Laying out IO file (1 file / 10240MiB)
^Cbs: 4 (f=4): [w(4)][97.9%][w=47.0MiB/s][w=12.0k IOPS][eta 00m:19s]
fio: terminating on signal 2
Jobs: 4 (f=4): [w(4)][98.0%][w=45.8MiB/s][w=11.7k IOPS][eta 00m:18s]
file1: (groupid=0, jobs=1): err= 0: pid=62: Thu Oct 16 06:56:59 2025
  write: IOPS=2526, BW=9.87MiB/s (10.3MB/s)(8697MiB/881234msec); 0 zone resets
    slat (usec): min=2, max=648843, avg=89.41, stdev=2766.77
    clat (usec): min=4, max=745569, avg=6240.77, stdev=18312.58
     lat (usec): min=307, max=745573, avg=6330.17, stdev=18630.44
    clat percentiles (usec):
     |  1.00th=[   611],  5.00th=[   824], 10.00th=[   971], 20.00th=[  1188],
     | 30.00th=[  1385], 40.00th=[  1582], 50.00th=[  1795], 60.00th=[  2073],
     | 70.00th=[  2442], 80.00th=[  3064], 90.00th=[  4883], 95.00th=[ 47973],
     | 99.00th=[ 73925], 99.50th=[ 83362], 99.90th=[196084], 99.95th=[252707],
     | 99.99th=[408945]
   bw (  KiB/s): min=    8, max=17616, per=24.97%, avg=10115.01, stdev=3199.17, samples=1760
   iops        : min=    2, max= 4404, avg=2528.73, stdev=799.79, samples=1760
  lat (usec)   : 10=0.01%, 50=0.01%, 100=0.01%, 250=0.01%, 500=0.25%
  lat (usec)   : 750=2.90%, 1000=7.92%
  lat (msec)   : 2=46.60%, 4=29.53%, 10=5.23%, 20=0.86%, 50=1.86%
  lat (msec)   : 100=4.46%, 250=0.33%, 500=0.05%, 750=0.01%
  cpu          : usr=1.35%, sys=4.38%, ctx=1781335, majf=0, minf=9
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=100.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.1%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,2226350,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=16
file1: (groupid=0, jobs=1): err= 0: pid=63: Thu Oct 16 06:56:59 2025
  write: IOPS=2532, BW=9.89MiB/s (10.4MB/s)(8718MiB/881227msec); 0 zone resets
    slat (usec): min=2, max=649086, avg=89.23, stdev=2781.74
    clat (usec): min=2, max=743460, avg=6225.72, stdev=18321.57
     lat (usec): min=322, max=761499, avg=6314.95, stdev=18643.48
    clat percentiles (usec):
     |  1.00th=[   611],  5.00th=[   824], 10.00th=[   971], 20.00th=[  1188],
     | 30.00th=[  1385], 40.00th=[  1582], 50.00th=[  1795], 60.00th=[  2073],
     | 70.00th=[  2442], 80.00th=[  3064], 90.00th=[  4817], 95.00th=[ 47973],
     | 99.00th=[ 74974], 99.50th=[ 83362], 99.90th=[196084], 99.95th=[254804],
     | 99.99th=[417334]
   bw (  KiB/s): min=    8, max=16974, per=25.04%, avg=10140.16, stdev=3190.16, samples=1760
   iops        : min=    2, max= 4243, avg=2535.02, stdev=797.53, samples=1760
  lat (usec)   : 4=0.01%, 10=0.01%, 20=0.01%, 50=0.01%, 100=0.01%
  lat (usec)   : 250=0.01%, 500=0.24%, 750=2.91%, 1000=7.99%
  lat (msec)   : 2=46.66%, 4=29.49%, 10=5.17%, 20=0.86%, 50=1.87%
  lat (msec)   : 100=4.44%, 250=0.32%, 500=0.05%, 750=0.01%
  cpu          : usr=1.32%, sys=4.44%, ctx=1782681, majf=0, minf=8
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=100.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.1%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,2231695,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=16
file1: (groupid=0, jobs=1): err= 0: pid=64: Thu Oct 16 06:56:59 2025
  write: IOPS=2535, BW=9.90MiB/s (10.4MB/s)(8726MiB/881228msec); 0 zone resets
    slat (usec): min=2, max=649123, avg=89.06, stdev=2720.21
    clat (usec): min=5, max=745532, avg=6219.58, stdev=18298.69
     lat (usec): min=308, max=745541, avg=6308.64, stdev=18631.88
    clat percentiles (usec):
     |  1.00th=[   611],  5.00th=[   824], 10.00th=[   971], 20.00th=[  1188],
     | 30.00th=[  1385], 40.00th=[  1582], 50.00th=[  1795], 60.00th=[  2073],
     | 70.00th=[  2442], 80.00th=[  3064], 90.00th=[  4817], 95.00th=[ 47973],
     | 99.00th=[ 73925], 99.50th=[ 83362], 99.90th=[196084], 99.95th=[250610],
     | 99.99th=[413139]
   bw (  KiB/s): min=   24, max=17763, per=25.06%, avg=10150.30, stdev=3215.62, samples=1760
   iops        : min=    6, max= 4440, avg=2537.55, stdev=803.90, samples=1760
  lat (usec)   : 10=0.01%, 20=0.01%, 50=0.01%, 100=0.01%, 250=0.01%
  lat (usec)   : 500=0.25%, 750=2.88%, 1000=7.92%
  lat (msec)   : 2=46.74%, 4=29.48%, 10=5.19%, 20=0.85%, 50=1.87%
  lat (msec)   : 100=4.44%, 250=0.32%, 500=0.04%, 750=0.01%
  cpu          : usr=1.31%, sys=4.40%, ctx=1783534, majf=0, minf=8
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=100.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.1%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,2233955,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=16
file1: (groupid=0, jobs=1): err= 0: pid=65: Thu Oct 16 06:56:59 2025
  write: IOPS=2531, BW=9.89MiB/s (10.4MB/s)(8715MiB/881236msec); 0 zone resets
    slat (usec): min=2, max=649113, avg=89.65, stdev=2773.70
    clat (usec): min=3, max=745785, avg=6226.88, stdev=18286.65
     lat (usec): min=311, max=760527, avg=6316.54, stdev=18608.24
    clat percentiles (usec):
     |  1.00th=[   611],  5.00th=[   832], 10.00th=[   971], 20.00th=[  1188],
     | 30.00th=[  1385], 40.00th=[  1582], 50.00th=[  1795], 60.00th=[  2073],
     | 70.00th=[  2442], 80.00th=[  3064], 90.00th=[  4883], 95.00th=[ 47973],
     | 99.00th=[ 74974], 99.50th=[ 83362], 99.90th=[198181], 99.95th=[250610],
     | 99.99th=[400557]
   bw (  KiB/s): min=    8, max=16558, per=25.03%, avg=10138.03, stdev=3213.85, samples=1760
   iops        : min=    2, max= 4139, avg=2534.49, stdev=803.46, samples=1760
  lat (usec)   : 4=0.01%, 50=0.01%, 100=0.01%, 250=0.01%, 500=0.23%
  lat (usec)   : 750=2.90%, 1000=7.96%
  lat (msec)   : 2=46.76%, 4=29.39%, 10=5.22%, 20=0.84%, 50=1.87%
  lat (msec)   : 100=4.45%, 250=0.33%, 500=0.04%, 750=0.01%
  cpu          : usr=1.36%, sys=4.43%, ctx=1781843, majf=0, minf=7
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=100.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.1%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,2231139,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=16

Run status group 0 (all jobs):
  WRITE: bw=39.6MiB/s (41.5MB/s), 9.87MiB/s-9.90MiB/s (10.3MB/s-10.4MB/s), io=34.0GiB (36.5GB), run=881227-881236msec
```
