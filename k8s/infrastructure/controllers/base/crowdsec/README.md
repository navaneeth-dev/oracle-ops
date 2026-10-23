# CrowdSec and Envoy WAF

Both clusters load this stack through the shared infrastructure base:

- CrowdSec LAPI stores decisions and credentials on TopoLVM PVCs.
- The agent reads the Envoy proxy's containerd access logs on each node.
- AppSec loads virtual patching and generic WAF rules.
- The Envoy bouncer checks IP decisions and sends requests to AppSec.
- `configs/base/envoy-gateway-system/securitypolicy.yaml` attaches external
  authorization to the `reverse-proxy` Gateway, covering its HTTPRoutes.

The fixed bouncer key is shared by two namespace-local Secrets, encrypted with
`sops -e` using the repository's age recipient. Flux decrypts them using
`flux-system/sops-age`. Console enrollment is optional and is not configured.
Never replace only one copy of the key; LAPI and the bouncer must agree.

External authorization and AppSec use fail-open behavior: detected attacks are
blocked while healthy, but traffic continues if the protection service fails.
Bodies are not forwarded to external authorization, so this configuration
inspects the URL, query string, and headers, not POST/upload payloads. The
installed Envoy API returns HTTP 413 above a configured `maxRequestBytes`, even
with fail-open enabled. Body inspection therefore needs a separate policy for
routes with an acceptable upload limit. Bot challenges are not enabled.

The bouncer uses Envoy's `X-Envoy-External-Address` header, resolved by the existing
ClientTrafficPolicy. Keep its trusted-hop configuration aligned with the actual
upstream proxy chain and confirm access logs identify the same client IP.

LAPI intentionally uses a single replica with persistent SQLite state for the
current single-node clusters. Move to PostgreSQL before increasing LAPI replicas.
Main-container memory requests equal limits and CPU is uncapped. The chart's
registration init containers retain their defaults: 10Mi requested, 50Mi limit.
These are initial memory
budgets; no CrowdSec workload history exists yet, so review observed peaks after
rollout. The pinned bouncer v0.8.2 image publishes both amd64 and arm64 manifests.

## Verification after Flux reconciliation

Run production commands from `clusters/prod` with `mise exec --`:

```sh
mise exec -- kubectl -n flux-system get kustomization crowdsec
mise exec -- kubectl -n crowdsec get helmrelease,pods,pvc,svc
mise exec -- kubectl -n envoy-gateway-system get helmrelease crowdsec-envoy-bouncer
mise exec -- kubectl -n envoy-gateway-system get securitypolicy crowdsec-ext-auth -o yaml
mise exec -- kubectl -n crowdsec exec deploy/crowdsec-lapi -- cscli bouncers list
mise exec -- kubectl -n crowdsec exec deploy/crowdsec-appsec -- cscli metrics show appsec
```

Confirm the SecurityPolicy is accepted and the bouncer is authenticated. From a
test client, request `/crowdsec-test-NtktlJHV4TfBSK3wvlhiOBnl` on an exposed app;
expect a WAF rejection and an AppSec alert. This test can ban the test client's
IP; use an address from which a temporary ban is acceptable.

References:
- https://docs.crowdsec.net/u/getting_started/installation/kubernetes/
- https://docs.crowdsec.net/docs/next/appsec/quickstart/envoy-gateway/
