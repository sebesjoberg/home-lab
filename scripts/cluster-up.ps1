$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot

kind create cluster --config "$root\kind\kind-config.yaml"
kubectl cluster-info --context kind-homelab

helm repo add argo https://argoproj.github.io/argo-helm 2>$null
helm repo update
helm upgrade --install argocd argo/argo-cd `
  --namespace argocd --create-namespace `
  --version 10.10.0 `
  -f "$root\infra\argocd\values.yaml" `
  --wait

Write-Host ""
Write-Host "Argo CD admin password:" -ForegroundColor Green
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) }
Write-Host ""
Write-Host "UI: run  kubectl -n argocd port-forward svc/argocd-server 8081:443  and open https://localhost:8081  (user admin)" -ForegroundColor Green
Write-Host "Once the repo is pushed and bootstrap/root.yaml has the real repoURL:  kubectl apply -f bootstrap/root.yaml" -ForegroundColor Yellow
