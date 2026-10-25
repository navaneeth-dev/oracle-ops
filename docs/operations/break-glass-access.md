# Break-glass API access

The Talos and Kubernetes APIs are not reachable from the internet. Admins
reach them at `10.0.0.11`, which the node advertises as a Tailscale subnet
route. If Tailscale on the node is broken, use OCI Bastion. Its session setup
is clumsy for daily use (see [OCI Bastion](../experiments/oci-bastion.md)) but
fine for emergencies.

## OCI Bastion port forwarding

1. Create a bastion in the prod subnet if none exists (OCI console:
   Identity & Security → Bastion), with your current public IP in the client
   CIDR allowlist. Bastions are free.
2. Create one port-forwarding session per API, targeting `10.0.0.11` port
   `50000` (Talos) and `6443` (Kubernetes), with your SSH public key.
3. Make `10.0.0.11` resolve locally so `talosctl` and `kubectl` keep using
   their normal configs and certificates, then open the tunnels with the SSH
   command each session shows, binding to that address:

```sh
sudo tailscale down
sudo ip addr add 10.0.0.11/32 dev lo
ssh -i <key> -N -L 10.0.0.11:50000:10.0.0.11:50000 -p 22 <talos-session-ocid>@host.bastion.ap-hyderabad-1.oci.oraclecloud.com &
ssh -i <key> -N -L 10.0.0.11:6443:10.0.0.11:6443 -p 22 <k8s-session-ocid>@host.bastion.ap-hyderabad-1.oci.oraclecloud.com &
# ...fix things from clusters/prod with talosctl and kubectl...
kill %1 %2
sudo ip addr del 10.0.0.11/32 dev lo
sudo tailscale up
```

Sessions expire after their TTL (up to 3 hours); create new ones if needed.
Delete the bastion afterwards if you created it.

## OCI serial console

The instance console connection in the OCI console shows the Talos dashboard
and boot logs even when the network is down. Talos has no shell, so it is for
diagnosis, not configuration.
