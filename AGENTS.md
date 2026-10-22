# Commit messages

Always use Conventional Commits for commit messages, including amended commits
(for example, `fix(cpu): right-size workload reservations`).

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
