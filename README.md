# homelab

Everything in the cluster is declared here. Argo CD watches `main` and applies it.

- `bootstrap/` — the single Application applied by hand, once. It points at `apps/`.
- `apps/` — one Argo CD Application per thing in the cluster.
- `infra/` — values and manifests for platform pieces (Argo CD, Sealed Secrets, MetalLB, ingress, ...).
- `workloads/` — our own applications.
- `kind/` — local two-node test cluster.
- `scripts/` — cluster up/down helpers.

## Local test cluster

    .\scripts\cluster-up.ps1
    .\scripts\cluster-down.ps1

## Secrets

Never commit a plain `Secret`. Seal it:

    kubectl create secret generic NAME -n NS --from-literal=key=value --dry-run=client -o yaml `
      | kubeseal --controller-name sealed-secrets-controller --controller-namespace kube-system -o yaml `
      > workloads/APP/sealed-secret.yaml

Back up the controller key the day the cluster is created:

    kubectl -n kube-system get secret -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > sealed-secrets-key.yaml

Store that outside the cluster, encrypted. Do not commit it.