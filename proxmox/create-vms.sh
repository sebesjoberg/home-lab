#!/usr/bin/env bash
# Run this ON the Proxmox host AFTER create-template.sh.
# Creates 3 Ubuntu VMs from the template with static IPs.
# Usage: bash create-vms.sh
set -euo pipefail

TEMPLATE_VMID=9000
STORAGE="local-lvm"
GATEWAY="192.168.0.1"          # your router
SSH_USER="sebastian"           # cloud-init user
# Paste your public SSH key here (from your Windows PC: cat ~/.ssh/id_ed25519.pub)
SSH_KEY_FILE="/tmp/homelab_ssh.pub"

# ── VM definitions ──────────────────────────────────────────────────
#   VMID  NAME       IP               CORES  MEMORY  DISK
VMS=(
  "110   cp-1       192.168.0.20/24  2      4096    32G"
  "120   worker-1   192.168.0.21/24  2      10240   50G"
  "130   worker-2   192.168.0.22/24  2      10240   50G"
)

# ── Prompt for SSH key if not already set ───────────────────────────
if [ ! -f "${SSH_KEY_FILE}" ]; then
  echo "Paste your SSH public key (from your PC: cat ~/.ssh/id_ed25519.pub),"
  echo "then press Enter:"
  read -r SSH_KEY
  echo "${SSH_KEY}" > "${SSH_KEY_FILE}"
fi

# ── Create VMs ──────────────────────────────────────────────────────
for vm in "${VMS[@]}"; do
  read -r VMID NAME IP CORES MEM DISK <<< "${vm}"

  echo "── Creating ${NAME} (VMID ${VMID}, ${IP}) ──"

  # Remove existing VM if present
  if qm status "${VMID}" &>/dev/null; then
    echo "  Destroying existing VM ${VMID}..."
    qm stop "${VMID}" --skiplock 2>/dev/null || true
    qm destroy "${VMID}" --purge
  fi

  # Clone from template
  qm clone "${TEMPLATE_VMID}" "${VMID}" --name "${NAME}" --full

  # Configure resources
  qm set "${VMID}" --cores "${CORES}" --memory "${MEM}"

  # Resize disk if different from template
  qm disk resize "${VMID}" scsi0 "${DISK}"

  # Cloud-init settings
  qm set "${VMID}" \
    --ciuser "${SSH_USER}" \
    --sshkeys "${SSH_KEY_FILE}" \
    --ipconfig0 "ip=${IP},gw=${GATEWAY}" \
    --nameserver "${GATEWAY}" \
    --searchdomain "lab.home"

  # Start the VM
  qm start "${VMID}"
  echo "  ${NAME} started."
done

echo ""
echo "All VMs created and started. Wait ~60s for cloud-init, then:"
echo "  ssh ${SSH_USER}@192.168.0.20   # cp-1"
echo "  ssh ${SSH_USER}@192.168.0.21   # worker-1"
echo "  ssh ${SSH_USER}@192.168.0.22   # worker-2"
