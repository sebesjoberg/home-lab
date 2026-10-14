$nodes = Select-String -Path ".\k3s-cluster\proxmox\create-vms.sh" -Pattern '(\d+\.\d+\.\d+\.\d+)/\d+' |
ForEach-Object { $_.Matches[0].Groups[1].Value }
foreach ($node in $nodes) {
  ssh "sebastian@$node" "sudo systemctl disable --now prometheus-node-exporter 2>/dev/null; sudo apt-get purge -y prometheus-node-exporter 2>/dev/null; true"
}
