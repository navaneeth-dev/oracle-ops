# Commit messages

Always use Conventional Commits for commit messages, including amended commits
(for example, `fix(cpu): right-size workload reservations`).

# Shared cluster application configuration

Oracle and Oracle-dev should run the same applications and normal application
configuration through the shared base. Put shared software, HelmRelease values,
and application storage integrations in base instead of duplicating them or
introducing different behavior in cluster overlays. Keep overlays limited to
settings that must differ between clusters. Running different application
software is an exception reserved for rare, explicitly intended testing; do not
introduce dev-only application differences by default.

# Status page and README

The public status page is Instatus at https://rizexor.instatus.com. When a
user-facing service is added, renamed or removed, update its Instatus monitor
and component in the same change, and tell the user if you cannot do it
yourself. Keep the README's overview and tech stack logos in sync as well.

# Documentation

Keep the README a high-level overview. Put details under `docs/`: removed
experiments and why they failed in `docs/experiments/`, earlier homelab
editions in `docs/previous-setups/`, and runbooks in `docs/operations/`.

# Kubernetes resource sizing

- **Memory:** Set request equal to limit, sized from historical peaks plus
  headroom.
- **CPU:** Set a realistic request; leave CPU uncapped where bursts matter.

# Kubernetes access

The production Kubernetes context is configured through mise in
`clusters/prod/mise.toml`. It sets `KUBECONFIG` to
`clusters/prod/talos/kubeconfig` and selects the production kubectl version.

Run production Kubernetes commands from `clusters/prod` with mise:

```sh
cd clusters/prod
mise exec -- kubectl config current-context
```

Use this configuration when inspecting or verifying production deployments.
The repository root mise configuration points to a different kubeconfig, so a
missing context there does not mean production cluster access is unavailable.
