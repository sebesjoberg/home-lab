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

## Secrets (Sealed Secrets)

Secrets are committed as `SealedSecret`s, encrypted with the controller's public key. The
controller (`kube-system`, key rotation off) decrypts them into normal `Secret`s with the same
name/namespace, which apps reference via `secretKeyRef` / `existingSecret`.

- **Kind:** `cluster-up.ps1` runs `kubectl apply -f infra/<app>/sealed`.
- **k3s:** Argo CD syncs `infra/<app>/sealed` as a source of each app (`apps/<app>.yaml`).

### Key

Both clusters share one key, stored outside the repo at `$HOME\.homelab\sealed-secrets-key.yaml`.
`cluster-up.ps1` applies it before the controller starts; `cluster-down.ps1` destroys the
in-cluster copy. Never commit it; keep a backup off this machine.

If it is missing, a new key is generated and old sealed files won't decrypt. Back it up:

    kubectl get secret -n kube-system -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml `
      > $HOME\.homelab\sealed-secrets-key.yaml

### New secret

    kubectl create secret generic NAME -n NS --from-literal=key=value --dry-run=client -o yaml `
      | kubeseal --controller-name sealed-secrets-controller --controller-namespace kube-system -o yaml `
      > infra/APP/sealed/NAME.yaml

Put it in `infra/<app>/sealed/` (new app: add the folder to `apps/<app>.yaml` and the Kind
script), then reference `NAME` from the app's values. Verify with `kubectl get secret NAME -n NS`.
