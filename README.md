# Oracle Ops

Highly available Kubernetes setup on Oracle Cloud Always Free Tier.

## Security

Only Network Load Balancers have a public IP, all Talos nodes have only Private
IPs and can be ONLY accessed via OCI Bastion.

## Updates

Updates are managed by Renovate Bot. I am using my own GitHub App to create and
merge PRs.

