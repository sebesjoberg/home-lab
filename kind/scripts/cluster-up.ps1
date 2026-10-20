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

# Monitoring: Prometheus + Loki store, Alloy (k8s-monitoring) collects, Grafana shows
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo add grafana https://grafana.github.io/helm-charts --force-update
helm repo add grafana-community https://grafana-community.github.io/helm-charts --force-update
helm repo update prometheus-community grafana grafana-community
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install prometheus prometheus-community/prometheus `
  --namespace monitoring `
  --version 29.37.0 `
  -f "$root\infra\prometheus\values.yaml" `
  --wait
helm upgrade --install loki grafana/loki `
  --namespace monitoring `
  --version 7.3.0 `
  -f "$root\infra\loki\values.yaml" `
  --wait
helm upgrade --install k8s-monitoring grafana/k8s-monitoring `
  --namespace monitoring `
  --version 4.5.3 `
  -f "$root\infra\k8s-monitoring\values.yaml" `
  -f "$root\infra\envs\kind\k8s-monitoring\values.yaml" `
  --wait
kubectl apply -f "$root\infra\grafana\sealed"
helm upgrade --install grafana-provisioning "$root\infra\grafana\provisioning" `
  --namespace monitoring
helm upgrade --install grafana grafana-community/grafana `
  --namespace monitoring `
  --version 13.5.1 `
  -f "$root\infra\grafana\values.yaml" `
  -f "$root\infra\envs\kind\grafana\values.yaml" `
  --wait

# Harbor (no Cloudflare in front, so no upload limit; push to harbor.localtest.me:8080)
helm repo add harbor https://helm.goharbor.io --force-update
helm repo update harbor
kubectl create namespace harbor --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$root\infra\harbor\sealed"
kubectl apply -f "$root\infra\envs\kind\harbor\manifests"
helm upgrade --install harbor harbor/harbor `
  --namespace harbor `
  --version 1.19.4 `
  -f "$root\infra\harbor\values.yaml" `
  -f "$root\infra\envs\kind\harbor\values.yaml" `
  --wait --timeout 10m

Write-Host ""
Write-Host "Cluster ready (about 5 minutes for Authentik):" -ForegroundColor Green
Write-Host "  http://auth.localtest.me:8080     Authentik" -ForegroundColor Green
Write-Host "  http://bao.localtest.me:8080      OpenBao" -ForegroundColor Green
Write-Host "  http://traefik.localtest.me:8080  Traefik" -ForegroundColor Green
Write-Host "  http://grafana.localtest.me:8080  Grafana" -ForegroundColor Green
Write-Host "  http://harbor.localtest.me:8080   Harbor" -ForegroundColor Green
