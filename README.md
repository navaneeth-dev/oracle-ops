# Oracle Ops

[Status Page](![Status](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2F[YOUR-STATUS-PAGE]%2Fsummary.json&query=%24.page.status&label=Status))

Highly available Kubernetes setup on Oracle Cloud Always Free Tier.

## TODO

- [ ] Remove all CPU limits
- [ ] Migrate all helm repo app-template to oci
- [ ] Fix alerting rules to Discord
- [ ] Scrape flux and add alerts to Discord for out of sync
- [ ] Backup postgres to s3 - authentik etc

## Security

Only Network Load Balancers have a public IP, all Talos nodes have only Private
IPs and can be ONLY accessed via OCI Bastion.

## Updates

Updates are managed by Renovate Bot. I am using my own GitHub App to create and
merge PRs.

## Benchmark

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

