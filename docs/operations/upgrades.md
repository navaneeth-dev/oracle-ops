# Upgrades

Renovate opens and merges update PRs through a dedicated GitHub App.

Prod is updated roughly every three months. Test changes on the dev cluster
first.

## Talos image and system extensions

`talos-schematic.yaml` at the repository root lists the system extensions.
`task common:genconfig` and `task common:upgrade` post it to the Image Factory,
which returns the same content-addressed ID for the same file, and use
`factory.talos.dev/oracle-installer/<id>:<version>`.

To change extensions, edit the schematic, then from `clusters/<cluster>/talos`:

1. `task common:genconfig` and `task common:applyconfig` (no reboot).
2. `task common:upgrade` (reboots the node; extensions only change here).
3. `talosctl get extensions` shows the new schematic ID.

Always upgrade through the task. A `talosctl upgrade` with another installer
image silently removes the extensions.

Each cluster's `multidoc/tailscale.sops.yaml` holds its Tailscale
`ExtensionServiceConfig`, using a `tag:talos` OAuth client secret.

Rollback options:

- `talosctl rollback`
- OCI console boot volume rollback

## Production upgrade procedure

Production is a single node. Schedule an Instatus maintenance covering all
Production components before applying configuration or starting an upgrade;
complete it only after checking workload and service health. Administration
uses the private IP through Tailscale. See [break-glass access](break-glass-access.md)
if that route is unavailable.

Run production commands with `mise exec --` from `clusters/prod` or its `talos`
directory so they use the production kubeconfig and talosconfig, not the root
mise defaults.

1. Check the Talos support matrix and both Talos and Cilium upgrade notes.
   Choose a Kubernetes minor supported by both. Upgrade Cilium one minor at a
   time and run the chart's preflight DaemonSet and policy validator before
   each minor upgrade; remove the preflight resources afterwards.
2. From `clusters/prod`, take an etcd snapshot with
   `mise exec -- talosctl etcd snapshot ../../.amp/in/<snapshot-name>`.
   Keep it private: it contains cluster secrets. `/.amp/in/` must be excluded
   in `.git/info/exclude` before using it.
3. Update `TALOS_VERSION` in `clusters/prod/talos/Taskfile.yml`, leaving
   `KUBERNETES_VERSION` at the running version until the OS upgrade is healthy.
   From `clusters/prod/talos`, run `mise exec -- task common:genconfig`, then
   `mise exec -- talosctl apply-config -f controlplane.yaml --dry-run`.
   Capture the diff privately and redact secrets before sharing it, including
   unchanged context lines containing discovery IDs/secrets or certificates.
4. During maintenance, run `mise exec -- task common:applyconfig` and
   `mise exec -- task common:upgrade`. Use a talosctl version matching the
   running server for the upgrade, then match the new version afterwards.
   Applying config alone does not install Talos. Allow several minutes for
   the reboot and TopoLVM-backed workloads to recover.
5. Check `talosctl version`, `talosctl get extensions`, `talosctl health`,
   node readiness, storage and pods before proceeding. Keep the expected
   schematic and Tailscale extension: they provide the administrative route.
6. Change the shared Cilium OCIRepository pin, commit and push each minor
   stage separately, then reconcile the `cilium` Kustomization and HelmRelease
   with `flux reconcile ... --with-source`. Wait for `cilium status --wait`
   and workload health before the next stage. Reconciling cannot deploy an
   unpushed local commit.
7. Update `KUBERNETES_VERSION` and the production kubectl pin, then run
   `mise exec -- talosctl upgrade-k8s --to <version> --dry-run` and
   `mise exec -- task common:upgrade-k8s`. The packaged command updates the
   control plane, kube-proxy, kubelet and bootstrap manifests in order.
   It also reapplies extra manifests, including metrics-server and the
   kubelet certificate approver. Review that dry-run diff too.
8. Verify all active pods, Flux Kustomizations and HelmReleases are Ready;
   verify `speed`, `authentik`, `grafana` and `start` under
   `*.oci.fossindia.ovh` return 200/302. Complete the Instatus maintenance and
   verify `https://rizexor.instatus.com/summary.json` reports healthy status.

Do not remove the production `service-account-issuer.yaml` patch when changing
API endpoints or certificate SANs. The issuer and audiences remain
`https://140.245.250.113:6443`: they identify existing service-account tokens
and need not be reachable. Regenerate future configs with the upgraded
Kubernetes version to avoid accidentally downgrading component images.

## 2026-10-25 production upgrade

- Talos `v1.12.9` → `v1.13.12` (stopped at the requested n−1 minor).
- Cilium `1.18.11` → `1.19.10` → `1.20.4`, through the shared base and Flux.
  Both preflight checks passed. Cilium 1.20 was chosen explicitly because
  Cilium 1.19 does not officially support Kubernetes 1.36.
- Kubernetes `v1.35.5` → `v1.36.5`, including control-plane components,
  kube-proxy and kubelet. The dry run found no removed-flag or API blockers.
- No Talos patch migration was required: `grubUseUKICmdline: true` avoids the
  new upgrade API's `extraKernelArgs` limitation, and neither `.machine.env`
  nor KubeSpan was configured. No Cilium policy/config migration was needed.
- Applied the pending public-IP SAN removal; verified the API certificate
  excludes `140.245.250.113`, while issuer/audiences remain pinned to it.
  The schematic stayed
  `4a0d65c669d46663f377e7161e50cfd570c401f26fd9e7bda34a0216b6f1922b`;
  the Tailscale extension is `1.102.2`.
- Saved a private, git-excluded etcd snapshot at
  `.amp/in/etcd-prod-before-20261025.snapshot` (revision `133165113`).
- The first OS upgrade request lost its connection during installer
  resolution, before reboot. After Image Factory returned the installer
  manifest, retrying the task with talosctl `v1.12.9` succeeded.
- Static API-server replacements stalled with kubelet volume-wait timeouts
  after the SAN change and during the Kubernetes upgrade. Restarting kubelet
  restored the API. The first Kubernetes run timed out at the scheduler;
  rerunning the same task resumed and completed the remaining steps.
- Final checks passed: Talos health, node/control-plane readiness, Cilium
  agent/operator and endpoint reachability, metrics API, all active pods and
  Flux resources, and 200/302 responses from all four service checks above.
- [Instatus maintenance](https://rizexor.instatus.com/cmvnifuaq08w913o7d3mwrvue)
  covered all Production components from **13:05 to 13:29 Asia/Calcutta**,
  finishing early within the planned 45-minute window. The public summary
  reported `UP` with no active maintenance after completion.
