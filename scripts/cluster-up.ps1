param(
  [string]$KeyFile = "$HOME\.homelab\sealed-secrets-key.yaml"
)
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
$root = Split-Path $PSScriptRoot

kind create cluster --config "$root\kind\kind-config.yaml"
kubectl cluster-info --context kind-homelab

if (Test-Path $KeyFile) {
  kubectl apply -f $KeyFile
}
else {
  Write-Host "No key at $KeyFile - a new one will be generated. Back it up." -ForegroundColor Yellow
}

helm repo add argo https://argoproj.github.io/argo-helm --force-update
helm repo update argo
helm upgrade --install argocd argo/argo-cd `
  --namespace argocd --create-namespace `
  --version 10.10.0 `
  -f "$root\infra\argocd\values.yaml" `
  --wait

kubectl apply -f "$root\bootstrap\root.yaml"

Write-Host "Log in with Authentik (about 5 minutes after startup):" -ForegroundColor Green
Write-Host "  http://auth.localtest.me:8080     Authentik" -ForegroundColor Green
Write-Host "  http://argocd.localtest.me:8080   Argo CD" -ForegroundColor Green
Write-Host "  http://bao.localtest.me:8080      OpenBao" -ForegroundColor Green
