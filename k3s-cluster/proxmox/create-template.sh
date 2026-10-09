#!/usr/bin/env bash
# Run this ON the Proxmox host to create a Ubuntu cloud-init VM template.
# Usage: bash create-template.sh
set -euo pipefail

TEMPLATE_VMID=9000
TEMPLATE_NAME="ubuntu-template"
STORAGE="local-lvm"            # change if your Proxmox uses a different storage
UBUNTU_IMG="ubuntu-24.04-server-cloudimg-amd64.img"
UBUNTU_URL="https://cloud-images.ubuntu.com/releases/24.04/release/${UBUNTU_IMG}"

# ── Download cloud image ────────────────────────────────────────────
if [ ! -f "/tmp/${UBUNTU_IMG}" ]; then
  echo "Downloading Ubuntu 24.04 cloud image..."
  wget -q --show-progress -O "/tmp/${UBUNTU_IMG}" "${UBUNTU_URL}"
else
  echo "Cloud image already downloaded, skipping."
fi

# ── Destroy old template if it exists ───────────────────────────────
if qm status "${TEMPLATE_VMID}" &>/dev/null; then
  echo "Removing existing VM ${TEMPLATE_VMID}..."
  qm destroy "${TEMPLATE_VMID}" --purge
fi

# ── Create the VM ───────────────────────────────────────────────────
echo "Creating VM ${TEMPLATE_VMID}..."
qm create "${TEMPLATE_VMID}" \
  --name "${TEMPLATE_NAME}" \
  --ostype l26 \
  --cpu host \
  --cores 2 \
  --memory 4096 \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-single \
  --agent enabled=1

# Import the cloud image as the boot disk
qm importdisk "${TEMPLATE_VMID}" "/tmp/${UBUNTU_IMG}" "${STORAGE}"
qm set "${TEMPLATE_VMID}" --scsi0 "${STORAGE}:vm-${TEMPLATE_VMID}-disk-0,discard=on,ssd=1"
qm set "${TEMPLATE_VMID}" --boot order=scsi0

# Add cloud-init drive
qm set "${TEMPLATE_VMID}" --ide2 "${STORAGE}:cloudinit"

# Cloud-init defaults (overridden per-clone)
qm set "${TEMPLATE_VMID}" --serial0 socket --vga serial0
qm set "${TEMPLATE_VMID}" --ipconfig0 ip=dhcp

# Resize disk to 32GB
qm disk resize "${TEMPLATE_VMID}" scsi0 32G

# ── Convert to template ─────────────────────────────────────────────
qm template "${TEMPLATE_VMID}"
echo "Template ${TEMPLATE_VMID} (${TEMPLATE_NAME}) created successfully."
