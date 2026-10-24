<div align="center">

# Oracle Ops

GitOps-managed Kubernetes homelab on the Oracle Cloud Always Free tier.

[![Status](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Frizexor.instatus.com%2Fsummary.json&query=%24.page.status&label=Status)](https://rizexor.instatus.com)

</div>

## Overview

- **Cluster:** a single Talos Linux control-plane node (Ampere A1) on Oracle
  Cloud, plus a separate dev cluster for testing changes.
- **GitOps:** Flux reconciles everything under [`k8s/`](k8s/). Renovate keeps
  charts and images up to date.
- **Ingress:** OCI Network Load Balancer → Envoy Gateway, with CrowdSec WAF on
  every route and authentik for single sign-on.
- **Storage:** TopoLVM local volumes, CloudNativePG for databases, VolSync
  restic backups.
- **Observability:** VictoriaMetrics, Grafana and Fluent Bit. Public status at
  [rizexor.instatus.com](https://rizexor.instatus.com).
- **Apps:** Jellyfin, Emby, Audiobookshelf, the arr stack, Seerr, Homepage and
  LibreSpeed.

## Tech stack

<table>
  <tr>
    <td align="center" width="120"><a href="https://www.oracle.com/cloud/free/"><img src="docs/assets/logos/oracle-cloud.svg" alt="Oracle Cloud" height="48"></a><br>Oracle Cloud</td>
    <td align="center" width="120"><a href="https://www.talos.dev"><img src="docs/assets/logos/talos.svg" alt="Talos" height="48"></a><br>Talos</td>
    <td align="center" width="120"><a href="https://kubernetes.io"><img src="docs/assets/logos/kubernetes.svg" alt="Kubernetes" height="48"></a><br>Kubernetes</td>
    <td align="center" width="120"><a href="https://fluxcd.io"><img src="docs/assets/logos/flux.svg" alt="Flux" height="48"></a><br>Flux</td>
    <td align="center" width="120"><a href="https://helm.sh"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/assets/logos/helm-dark.svg"><img src="docs/assets/logos/helm.svg" alt="Helm" height="48"></picture></a><br>Helm</td>
    <td align="center" width="120"><a href="https://getsops.io"><img src="docs/assets/logos/sops.svg" alt="SOPS" height="48"></a><br>SOPS</td>
  </tr>
  <tr>
    <td align="center" width="120"><a href="https://docs.renovatebot.com"><img src="docs/assets/logos/renovate.svg" alt="Renovate" height="48"></a><br>Renovate</td>
    <td align="center" width="120"><a href="https://cilium.io"><img src="docs/assets/logos/cilium.svg" alt="Cilium" height="48"></a><br>Cilium</td>
    <td align="center" width="120"><a href="https://gateway.envoyproxy.io"><img src="docs/assets/logos/envoy-gateway.svg" alt="Envoy Gateway" height="48"></a><br>Envoy Gateway</td>
    <td align="center" width="120"><a href="https://cert-manager.io"><img src="docs/assets/logos/cert-manager.svg" alt="cert-manager" height="48"></a><br>cert-manager</td>
    <td align="center" width="120"><a href="https://www.crowdsec.net"><img src="docs/assets/logos/crowdsec.svg" alt="CrowdSec" height="48"></a><br>CrowdSec</td>
    <td align="center" width="120"><a href="https://goauthentik.io"><img src="docs/assets/logos/authentik.svg" alt="authentik" height="48"></a><br>authentik</td>
  </tr>
  <tr>
    <td align="center" width="120"><a href="https://cloudnative-pg.io"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/assets/logos/cloudnativepg-dark.svg"><img src="docs/assets/logos/cloudnativepg.svg" alt="CloudNativePG" height="48"></picture></a><br>CloudNativePG</td>
    <td align="center" width="120"><a href="https://github.com/topolvm/topolvm"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/assets/logos/topolvm-dark.svg"><img src="docs/assets/logos/topolvm.svg" alt="TopoLVM" height="48"></picture></a><br>TopoLVM</td>
    <td align="center" width="120"><a href="https://volsync.readthedocs.io"><img src="docs/assets/logos/volsync.svg" alt="VolSync" height="48"></a><br>VolSync</td>
    <td align="center" width="120"><a href="https://victoriametrics.com"><img src="docs/assets/logos/victoriametrics.svg" alt="VictoriaMetrics" height="48"></a><br>VictoriaMetrics</td>
    <td align="center" width="120"><a href="https://grafana.com"><img src="docs/assets/logos/grafana.svg" alt="Grafana" height="48"></a><br>Grafana</td>
    <td align="center" width="120"><a href="https://fluentbit.io"><img src="docs/assets/logos/fluent-bit.svg" alt="Fluent Bit" height="48"></a><br>Fluent Bit</td>
  </tr>
</table>

## Repository layout

| Path | Contents |
|---|---|
| [`clusters/`](clusters/) | Talos machine config and OCI infrastructure per cluster |
| [`k8s/`](k8s/) | Flux manifests: shared `base` and per-cluster overlays |
| [`docs/`](docs/) | Experiments, previous setups, runbooks and roadmap |

## Security

The prod Talos node has an ephemeral public IP and shares a public subnet with
both Network Load Balancers. See [OCI Bastion](docs/experiments/oci-bastion.md)
for why Bastion is not used for API access.
