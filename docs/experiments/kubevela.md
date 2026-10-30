# KubeVela

KubeVela 1.10.9 (`vela-core` Helm release `kubevela` in `vela-system`) and its
VelaUX addon ran on the prod cluster from 2026-07-19 to 2026-10-30. It was
installed by hand with Helm, outside Flux, and only ran a `test` webservice
application in a Vela-created `dev` namespace.

It was removed during an identity and access review because:

1. **It was outside GitOps.** Nothing in this repository described it, so it
   drifted from the declared cluster state and would not be rebuilt or
   upgraded with everything else.

2. **It exposed a cluster admin UI to the internet.** VelaUX was published at
   `kubevela.oci.fossindia.ovh` through the shared gateway with only its own
   local login, not authentik. VelaUX and its cluster gateway hold broad
   cluster-wide write permissions, so a weak or leaked VelaUX credential would
   have given an attacker control of the cluster.

3. **Nothing used it.** Applications are deployed with Flux HelmReleases;
   KubeVela only ever ran the test application.

## Removal

The Vela `Application`s were deleted first so the controller cleaned up their
workloads, then the Helm release, the `velaux` HTTPRoute, the `*.oam.dev`
CRDs, the remaining KubeVela cluster roles and the Vela-created `vela-system`,
`dev` and `prod` namespaces. The Vela labels were removed from `default`.
