# homelab

Two environments: Kind (local dev) and k3s on Proxmox (always-on).

## Structure

- `infra/` — shared base values + `infra/envs/kind/` and `infra/envs/k3s/` overrides.
- `apps/k3s/` — Argo CD Applications for the k3s cluster.
- `bootstrap/` — root Argo CD Application for k3s.
- `k3s-cluster/` — Proxmox VM provisioning and cluster scripts.
- `kind/` — Kind config and scripts (no Argo CD, direct Helm installs).
- `workloads/` — applications.

## Kind (local dev)

    .\kind\scripts\cluster-up.ps1
    .\kind\scripts\cluster-down.ps1

## k3s (Proxmox)

    .\k3s-cluster\scripts\cluster-up.ps1
    .\k3s-cluster\scripts\cluster-down.ps1

## Secrets

Seal before committing:

    kubectl create secret generic NAME -n NS --from-literal=key=value --dry-run=client -o yaml `
      | kubeseal --controller-name sealed-secrets-controller --controller-namespace kube-system -o yaml `
      > infra/APP/sealed/secret.yaml

Back up the sealing key on day one. Do not commit it.
