# Opt-in ZeroFS storage for the arr stack

Production mounts the shared `arr-zerofs` PVC at `/zerofs` in qBittorrent,
Sonarr and Radarr. Existing `/data` mounts and media stay in place. Emby is
unchanged and does not yet have access to this filesystem. App configuration and
SQLite databases remain on their existing local config PVCs.

The PVC requests 200 decimal GB; the gateway enforces the **shared** 200 GB logical
quota, not a separate 200 GB allocation per claim. The standalone gateway retains
its 8 GiB local cache PVC (6 decimal GB cache). Neither media nor cache uses VolSync.

## Deployment and direct setup

Flux manages the permanent infrastructure, PVC and app mounts. There are no
configuration or directory Jobs. Directory creation and application API changes
are direct operations, not recurring reconciliation.

On deployment, the gateway switches from the historical benchmark prefix
`rizexor-media/zerofs-test` to `rizexor-media/zerofs`, using the same OVH Secret and
ZeroFS encryption password. This opens a fresh filesystem; it does not migrate
old benchmark data. The gateway init container clears disposable local bucket
cache once before opening the new prefix. Historical objects and benchmark claims
are retained. Do not switch an active media filesystem's prefix later.

After deploying the manifests through Flux, run from the repository root:

```sh
python3 k8s/apps/oracle/arr-zerofs/scripts/prepare-volume.py
python3 k8s/apps/oracle/arr-zerofs/scripts/configure-local.py --dry-run
python3 k8s/apps/oracle/arr-zerofs/scripts/configure-local.py
```

The first command checks the permanent backend and gateway readiness, creates a
short-lived utility Pod to run shell-equivalent Python commands against the PVC,
then deletes it. It creates directories with UID/GID 1000 and mode 775 and verifies
write/read/fsync and a cross-directory hardlink as that UID. It neither copies nor
moves existing media. It preserves the current `/data` layout exactly:

```text
/zerofs/
├── torrents/
│   ├── books/
│   ├── movies/
│   ├── music/
│   ├── tv/
│   └── audiobooks/
├── media/
│   ├── books/
│   ├── movies/
│   ├── music/
│   └── tv/
└── usenet/
    ├── incomplete/
    └── complete/
```

The API command reads existing API keys into memory through kubectl and uses
localhost-only port forwards. It adds the following, without moving any existing
movie/series or starting downloads:

| Application | Additional root | qBittorrent category | Category save path |
| --- | --- | --- | --- |
| Radarr | `/zerofs/media/movies` | `radarr-zerofs` | `/zerofs/torrents/movies` |
| Sonarr | `/zerofs/media/tv` | `sonarr-zerofs` | `/zerofs/torrents/tv` |

Each arr app gets a `zerofs` tag, a tagged `qBittorrent ZeroFS` client cloned from
its existing untagged qBittorrent client, and a tag-scoped torrent-only delay
profile. The profile prevents SABnzbd downloads on local `/data` being selected
for these items. Default clients and profiles are preserved. The categories
explicitly disable a separate incomplete-download directory, matching current
qBittorrent behavior and keeping all data on the shared filesystem.

For an item to use ZeroFS, select **both its new root folder and the `zerofs` tag**.
The root determines the final library location; the tag selects the torrent
client/category. Existing untagged items continue using current routes. Hardlinks
are required and checked before setup; seeding and library paths share one PVC.

## Verification and limits

```sh
python3 -m unittest discover -s k8s/apps/oracle/arr-zerofs/scripts -p 'test_*.py'
```

After setup, inspect the new roots and download clients in both arr UIs. Start a
single deliberately selected download, check its category/save path, and confirm
import produces the same inode under torrents and media. Do not move an existing
library to this filesystem as part of the first check.

Historical fio results reached about 32 MiB/s with an explicit 32 MiB/s cap; they
do not establish support for sustained 48 MiB/s downloads or concurrent playback
and seeding. Emby playback from ZeroFS needs a separate integration step. Existing
Emby playback is unaffected by adding these three app mounts.
