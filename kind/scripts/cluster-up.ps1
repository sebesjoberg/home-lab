param(
  [string]$KeyFile = "$HOME\.homelab\sealed-secrets-key.yaml"
)
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
$root = Split-Path (Split-Path $PSScriptRoot)

kind create cluster --config "$root\kind\kind-config.yaml"
kubectl cluster-info --context kind-homelab

# Sealed secrets
helm repo add sealed-secrets https://bitnami.github.io/sealed-secrets --force-update
helm repo update sealed-secrets
if (Test-Path $KeyFile) {
  kubectl apply -f $KeyFile
}
else {
  Write-Host "No key at $KeyFile - a new one will be generated. Back it up." -ForegroundColor Yellow
}
helm upgrade --install sealed-secrets sealed-secrets/sealed-secrets `
  --namespace kube-system `
  --version 2.20.0 `
  -f "$root\infra\sealed-secrets\values.yaml" `
  --wait

# Traefik
helm repo add traefik https://traefik.github.io/charts --force-update
helm repo update traefik
helm upgrade --install traefik traefik/traefik `
  --namespace traefik --create-namespace `
  --version 41.6.1 `
  -f "$root\infra\traefik\values.yaml" `
  -f "$root\infra\envs\kind\traefik\values.yaml" `
  --wait

# Authentik
helm repo add authentik https://charts.goauthentik.io --force-update
helm repo update authentik
kubectl create namespace authentik --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$root\infra\authentik\sealed"
kubectl apply -f "$root\infra\envs\kind\authentik\manifests"
helm upgrade --install authentik authentik/authentik `
  --namespace authentik `
  --version 2026.8.3 `
  -f "$root\infra\authentik\values.yaml" `
  -f "$root\infra\envs\kind\authentik\values.yaml" `
  --wait

# OpenBao
helm repo add openbao https://openbao.github.io/openbao-helm --force-update
helm repo update openbao
kubectl create namespace openbao --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$root\infra\openbao\sealed"
helm upgrade --install openbao openbao/openbao `
  --namespace openbao `
  --version 0.30.2 `
  -f "$root\infra\openbao\values.yaml" `
  -f "$root\infra\envs\kind\openbao\values.yaml" `
  --wait

# External Secrets
helm repo add external-secrets https://charts.external-secrets.io --force-update
helm repo update external-secrets
helm upgrade --install external-secrets external-secrets/external-secrets `
  --namespace external-secrets --create-namespace `
  --version 2.11.0 `
  --wait
kubectl apply -f "$root\infra\external-secrets\manifests"

# CoreDNS
kubectl apply -f "$root\infra\envs\kind\coredns\manifests"

Write-Host ""
Write-Host "Cluster ready (about 5 minutes for Authentik):" -ForegroundColor Green
Write-Host "  http://auth.localtest.me:8080     Authentik" -ForegroundColor Green
Write-Host "  http://bao.localtest.me:8080      OpenBao" -ForegroundColor Green
Write-Host "  http://traefik.localtest.me:8080  Traefik" -ForegroundColor Green
