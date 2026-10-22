#!/bin/sh
set -eu
mode="${1:-}"
gib="${2:-2}"
case "$gib" in 2|8|20) ;; *) echo 'size must be 2, 8, or 20 GiB' >&2; exit 2;; esac
mkdir -p /data/fio
file="/data/fio/media-${gib}GiB.bin"
jobs=1
max_jobs=1
rate=32m
if [ "$mode" = parallel ]; then
  jobs=4
  max_jobs=8
  rate=8m
fi
# Bounded synchronous workers, direct I/O, and a 32 MiB/s aggregate traffic cap.
set -- --max-jobs="$max_jobs" --name=media --filename="$file" --size="${gib}g" \
  --ioengine=psync --iodepth=1 --numjobs="$jobs" --direct=1 \
  --rate="$rate" --group_reporting=1 --output-format=json --aux-path=/tmp
case "$mode" in
  write)
    test ! -e "$file" || { echo 'Refusing to overwrite an existing test file' >&2; exit 2; }
    exec fio "$@" --rw=write --bs=1m --refill_buffers=1 --scramble_buffers=1 \
      --buffer_compress_percentage=0 --dedupe_percentage=0 \
      --verify=crc32c --do_verify=0 --end_fsync=1 ;;
  read)
    exec fio "$@" --rw=read --bs=1m --readonly --allow_file_create=0 ;;
  verify)
    exec fio "$@" --rw=read --bs=1m --readonly --allow_file_create=0 \
      --verify=crc32c --verify_only=1 --verify_fatal=1 --verify_dump=0 ;;
  random)
    exec fio "$@" --rw=randread --bs=128k --readonly --allow_file_create=0 \
      --time_based=1 --runtime=60 --randrepeat=1 ;;
  parallel)
    # Four independent readers, still capped at 32 MiB/s in aggregate.
    exec fio "$@" --rw=randread --bs=128k \
      --readonly --allow_file_create=0 --time_based=1 --runtime=60 --randrepeat=1 ;;
  warm)
    # Reads the same 1 GiB range. Run twice to compare first/repeated access.
    exec fio "$@" --size=1g --rw=read --bs=1m --readonly --allow_file_create=0 ;;
  *) echo 'usage: fio.sh write|read|verify|random|parallel|warm [2|8|20]' >&2; exit 2 ;;
esac
