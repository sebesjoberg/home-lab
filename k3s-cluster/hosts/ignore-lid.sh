#!/usr/bin/env bash
# Run this ON a laptop host (Proxmox host or Ubuntu worker) so closing the lid
# doesn't suspend it. Ubuntu suspends on lid close by default, even on mains power.
# Usage: sudo bash ignore-lid.sh
set -euo pipefail

CONF="/etc/systemd/logind.conf.d/ignore-lid.conf"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root (sudo bash ignore-lid.sh)." >&2
  exit 1
fi

mkdir -p "$(dirname "${CONF}")"
cat > "${CONF}" <<'EOF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
EOF

systemctl restart systemd-logind
echo "Lid close is ignored."
