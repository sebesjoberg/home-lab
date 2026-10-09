$ErrorActionPreference = "Stop"
$root = Split-Path (Split-Path $PSScriptRoot)
$user = "sebastian"

# Parse IPs from create-vms.sh
$nodes = Select-String -Path "$root\k3s-cluster\proxmox\create-vms.sh" -Pattern '(\d+\.\d+\.\d+\.\d+)/\d+' |
  ForEach-Object { $_.Matches[0].Groups[1].Value }

# Uninstall workers first (reverse order), then control plane last
[array]::Reverse($nodes)

foreach ($node in $nodes) {
  Write-Host "Stopping k3s on $node..." -ForegroundColor Yellow
  ssh "${user}@${node}" "sudo /usr/local/bin/k3s-agent-uninstall.sh 2>/dev/null || sudo /usr/local/bin/k3s-uninstall.sh 2>/dev/null || true"
  Write-Host "  Done." -ForegroundColor Green
}

Write-Host ""
Write-Host "k3s cluster removed from all nodes." -ForegroundColor Green
Write-Host "VMs are still running - stop them from Proxmox if needed." -ForegroundColor Yellow
