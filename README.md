# Oracle Ops

Highly available Kubernetes setup on Oracle Cloud Always Free Tier.

## Security

Only Network Load Balancers have a public IP, all Talos nodes have only Private
IPs and can be ONLY accessed via OCI Bastion.

## Updates

Updates are managed by Renovate Bot. I am using my own GitHub App to create and
merge PRs.

## Benchmark

```
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

