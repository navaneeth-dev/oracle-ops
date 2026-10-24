# OCI Bastion

OCI Bastion can reach the private Talos nodes, but it is a poor fit for daily
Kubernetes and Talos API access, both for scripting and for humans.

1. **Every connection needs a session first.** A port-forwarding session must
   be created for each target IP and port, then waited on until it becomes
   active, before `ssh -L` can open the tunnel. Talos has no SSH daemon, so
   only port-forwarding sessions work, and the Kubernetes API (6443) and the
   Talos API (50000) each need their own.

2. **Sessions expire.** Sessions have a maximum lifetime of a few hours, so
   long-running work and idle terminals lose the tunnel and the whole flow
   starts again.

3. **Scripting is fragile.** Automation must call the OCI CLI to create a
   session, poll its state, extract the generated SSH command, keep a
   background `ssh` process alive and clean it up afterwards. Tools such as
   Taskfile targets, Renovate checks or CI cannot simply run `kubectl` or
   `talosctl`.

4. **Configs must point at the tunnel.** `kubeconfig` and `talosconfig` must
   target `127.0.0.1`, and the API certificates must include that address
   as a SAN.

## Better alternative: GCP Identity-Aware Proxy

GCP IAP TCP forwarding (`gcloud compute start-iap-tunnel`) gives the same
private access with a much better experience. Access is checked against the
user's Google identity and IAM on each connection, no session is created in
advance, there is no fixed session expiry to manage, and the command can be
scripted directly. IAP for HTTPS can also put authentication in front of web
applications.

IAP is a Google Cloud feature and is not available on OCI or other clouds.
On this cluster, the closest equivalents are a WireGuard or Tailscale tunnel
into the VCN, or restricting the API load balancer listeners to known source
IPs with a Network Security Group.
