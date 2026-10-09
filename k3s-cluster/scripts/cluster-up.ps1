param(
  [string]$KeyFile = "$HOME\.homelab\sealed-secrets-key.yaml"
)
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
$root = Split-Path (Split-Path $PSScriptRoot)

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
  -f "$root\infra\envs\k3s\argocd\values.yaml" `
  --wait

kubectl apply -f "$root\bootstrap\root-k3s.yaml"

Write-Host "Log in with Authentik (about 5 minutes after startup):" -ForegroundColor Green
Write-Host "  http://auth.lab.home       Authentik" -ForegroundColor Green
Write-Host "  http://argocd.lab.home     Argo CD" -ForegroundColor Green
Write-Host "  http://bao.lab.home        OpenBao" -ForegroundColor Green
