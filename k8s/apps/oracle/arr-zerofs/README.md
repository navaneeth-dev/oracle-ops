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

After deploying the manifests through Flux, perform these one-time operations
with direct `kubectl exec` commands and the application UIs/APIs. Run production
kubectl commands from `clusters/prod` with `mise exec -- kubectl`.

1. Confirm the gateway is Ready on the permanent backend, the `arr-zerofs` PVC is
   Bound, and all three applications have `/zerofs` mounted.
2. Create the directories below on the mounted filesystem. Set ownership to
   UID/GID 1000 and directory permissions to 775. Use a temporary utility Pod only
   if elevated permissions are needed; delete it afterward.
3. As UID/GID 1000, write a small temporary file in `/zerofs/torrents/movies`,
   hardlink it into `/zerofs/media/movies`, and verify matching inode numbers,
   link count two, and readable contents. Remove both temporary names afterward.
4. Configure the additional roots, categories, tagged clients and delay profiles
   described below through the app UIs/APIs. Preserve existing defaults and do not
   move media or start downloads during configuration.

No setup scripts are retained or run by GitOps. Directory creation preserves the
current `/data` layout exactly:

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

Configure these additional roots and qBittorrent categories:

| Application | Additional root | qBittorrent category | Category save path |
| --- | --- | --- | --- |
| Radarr | `/zerofs/media/movies` | `radarr-zerofs` | `/zerofs/torrents/movies` |
| Sonarr | `/zerofs/media/tv` | `sonarr-zerofs` | `/zerofs/torrents/tv` |

In each arr app, add a `zerofs` tag, a tagged `qBittorrent ZeroFS` client copied
from its existing untagged qBittorrent client (using the corresponding category
above), and a tag-scoped torrent-only delay profile. The profile prevents SABnzbd downloads on local `/data` being selected
for these items. Preserve default clients and profiles. Explicitly disable a separate incomplete
download directory for both categories, matching current qBittorrent behavior and
keeping all data on the shared filesystem.

For an item to use ZeroFS, select **both its new root folder and the `zerofs` tag**.
The root determines the final library location; the tag selects the torrent
client/category. Existing untagged items continue using current routes. Hardlinks
are required and checked before setup; seeding and library paths share one PVC.

## Verification and limits

After setup, inspect the new roots and download clients in both arr UIs. Start a
single deliberately selected download, check its category/save path, and confirm
import produces the same inode under torrents and media. Do not move an existing
library to this filesystem as part of the first check.

Historical fio results reached about 32 MiB/s with an explicit 32 MiB/s cap; they
do not establish support for sustained 48 MiB/s downloads or concurrent playback
and seeding. Emby playback from ZeroFS needs a separate integration step. Existing
Emby playback is unaffected by adding these three app mounts.
