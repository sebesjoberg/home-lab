param(
  [string]$KeyFile = "$HOME\.homelab\sealed-secrets-key.yaml"
)
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
$root = Split-Path (Split-Path $PSScriptRoot)
$user = "sebastian"
$ssh = @("-o", "StrictHostKeyChecking=accept-new")
$proxmox = "192.168.0.10"

# Parse IPs from create-vms.sh and bare-metal.txt - first is the control plane, rest are workers
function Get-NodeIps($path) {
  Select-String -Path $path -Pattern '(\d+\.\d+\.\d+\.\d+)/\d+' | ForEach-Object { $_.Matches[0].Groups[1].Value }
}
$bareMetal = @(Get-NodeIps "$root\k3s-cluster\hosts\bare-metal.txt")
$nodes = @(Get-NodeIps "$root\k3s-cluster\proxmox\create-vms.sh") + $bareMetal
$cp = $nodes[0]
$workers = $nodes | Select-Object -Skip 1

# Proxmox host exporters run outside the cluster; Alloy scrapes them.
Write-Host "Ensuring exporters on Proxmox $proxmox..." -ForegroundColor Yellow
ssh @ssh "root@${proxmox}" "dpkg -s prometheus-node-exporter prometheus-node-exporter-collectors nvme-cli >/dev/null 2>&1 || { apt-get update -qq; apt-get install -y prometheus-node-exporter prometheus-node-exporter-collectors nvme-cli; }; systemctl enable --now prometheus-node-exporter prometheus-node-exporter-nvme.timer; systemctl start prometheus-node-exporter-nvme.service"

# Bare-metal hosts are laptops: keep them awake with the lid closed and CPU boost off
foreach ($node in $bareMetal) {
  Write-Host "Preparing bare-metal host $node..." -ForegroundColor Yellow
  foreach ($script in "ignore-lid.sh", "disable-boost.sh") {
    # PowerShell pipes with CRLF line endings, which bash can't run
    Get-Content -Raw "$root\k3s-cluster\hosts\$script" | ssh @ssh "${user}@${node}" "tr -d '\r' | sudo bash -s"
  }
}

# Control plane. Traefik is installed by Argo CD, so disable the bundled one.
Write-Host "Installing k3s server on $cp..." -ForegroundColor Yellow
ssh @ssh "${user}@${cp}" "systemctl is-active --quiet k3s || curl -sfL https://get.k3s.io | sh -s - server --disable traefik --tls-san $cp --node-ip $cp"
$token = (ssh @ssh "${user}@${cp}" "sudo cat /var/lib/rancher/k3s/server/node-token").Trim()

# Workers
foreach ($node in $workers) {
  Write-Host "Joining $node to the cluster..." -ForegroundColor Yellow
  ssh @ssh "${user}@${node}" "systemctl is-active --quiet k3s-agent || curl -sfL https://get.k3s.io | K3S_URL=https://${cp}:6443 K3S_TOKEN=$token sh -s - agent --node-ip $node"
}

# Merge kubeconfig into ~/.kube/config as context "k3s-homelab"
$kubeDir = "$HOME\.kube"
$kubeConfig = "$kubeDir\config"
$k3sConfig = "$kubeDir\k3s-homelab.yaml"
New-Item -ItemType Directory -Force $kubeDir | Out-Null
(ssh @ssh "${user}@${cp}" "sudo cat /etc/rancher/k3s/k3s.yaml") -join "`n" `
  -replace '127\.0\.0\.1', $cp `
  -replace '(?m)^(\s*(-\s*)?(name|cluster|user|current-context):\s*)default\s*$', '${1}k3s-homelab' |
Set-Content -NoNewline $k3sConfig
if (Test-Path $kubeConfig) {
  foreach ($kind in "context", "cluster", "user") {
    try { kubectl config "delete-$kind" k3s-homelab --kubeconfig $kubeConfig 2>$null | Out-Null } catch {}
  }
  $env:KUBECONFIG = "$kubeConfig;$k3sConfig"
  $merged = kubectl config view --flatten
  Remove-Item Env:KUBECONFIG
  $merged | Set-Content $kubeConfig
}
else {
  Copy-Item $k3sConfig $kubeConfig
}
kubectl config use-context k3s-homelab

Write-Host "Waiting for $($nodes.Count) nodes to be Ready..." -ForegroundColor Yellow
while (@(kubectl get nodes -o name).Count -lt $nodes.Count) { Start-Sleep -Seconds 5 }
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Bare-metal hosts have a big disk and the whole machine to themselves. Keep them
# for heavy workloads: those select the label and tolerate the taint.
foreach ($node in $bareMetal) {
  $name = (ssh @ssh "${user}@${node}" "hostname").Trim()
  kubectl label node $name sebhome.homes/dedicated=heavy --overwrite
  kubectl taint node $name sebhome.homes/dedicated=heavy:NoSchedule --overwrite
}

if (Test-Path $KeyFile) {
  # The backup carries a resourceVersion, so re-applying it to a running cluster conflicts
  if (-not (kubectl get -f $KeyFile --ignore-not-found -o name)) {
    kubectl apply -f $KeyFile
  }
}
else {
  Write-Host "No key at $KeyFile - a new one will be generated. Back it up." -ForegroundColor Yellow
}

# Helm only bootstraps Argo CD; after that it manages itself (apps/argocd.yaml),
# and a second helm upgrade conflicts with its changes.
if (-not (kubectl get deployment argocd-server -n argocd --ignore-not-found -o name)) {
  helm repo add argo https://argoproj.github.io/argo-helm --force-update
  helm repo update argo
  helm upgrade --install argocd argo/argo-cd `
    --namespace argocd --create-namespace `
    --version 10.10.0 `
    -f "$root\infra\argocd\values.yaml" `
    -f "$root\infra\envs\k3s\argocd\values.yaml" `
    --wait
}

kubectl apply -f "$root\bootstrap\root-k3s.yaml"

Write-Host "Log in with Authentik (about 5 minutes after startup):" -ForegroundColor Green
Write-Host "  http://auth.sebhome.homes      Authentik" -ForegroundColor Green
Write-Host "  http://argocd.sebhome.homes     Argo CD" -ForegroundColor Green
Write-Host "  http://bao.sebhome.homes        OpenBao" -ForegroundColor Green
Write-Host "  http://grafana.sebhome.homes    Grafana" -ForegroundColor Green
