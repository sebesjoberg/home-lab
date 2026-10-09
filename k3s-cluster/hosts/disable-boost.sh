#!/usr/bin/env bash
# Run this ON a bare-metal host (Proxmox host or Ubuntu worker) to disable
# CPU boost/turbo now and on every boot. Survives BIOS/CMOS resets.
# Usage: sudo bash disable-boost.sh
set -euo pipefail

RUNNER="/usr/local/sbin/disable-cpu-boost"
UNIT="/etc/systemd/system/disable-cpu-boost.service"

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root (sudo bash disable-boost.sh)." >&2
  exit 1
fi

# ── Runner script (called by systemd at boot) ───────────────────────
cat > "${RUNNER}" <<'EOF'
#!/bin/sh
# Disables CPU boost for whichever cpufreq driver is active.
done=0

# Intel (intel_pstate / intel_cpufreq)
if [ -w /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
  echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo && done=1
fi

# AMD/generic (acpi-cpufreq, global boost knob)
if [ -w /sys/devices/system/cpu/cpufreq/boost ]; then
  echo 0 > /sys/devices/system/cpu/cpufreq/boost && done=1
fi

# amd-pstate on newer kernels (per-policy boost knob)
for f in /sys/devices/system/cpu/cpufreq/policy*/boost; do
  [ -w "$f" ] && echo 0 > "$f" && done=1
done

if [ "$done" -eq 1 ]; then
  echo "CPU boost disabled."
else
  echo "No writable boost control found (driver may not support it)." >&2
  exit 1
fi
EOF
chmod 755 "${RUNNER}"

# ── systemd unit ────────────────────────────────────────────────────
cat > "${UNIT}" <<EOF
[Unit]
Description=Disable CPU boost/turbo
After=sysinit.target

[Service]
Type=oneshot
ExecStart=${RUNNER}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now disable-cpu-boost.service

# ── Show result ─────────────────────────────────────────────────────
echo
echo "Driver: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null || echo unknown)"
[ -r /sys/devices/system/cpu/cpufreq/boost ] && \
  echo "cpufreq/boost: $(cat /sys/devices/system/cpu/cpufreq/boost) (0 = off)"
[ -r /sys/devices/system/cpu/intel_pstate/no_turbo ] && \
  echo "intel_pstate/no_turbo: $(cat /sys/devices/system/cpu/intel_pstate/no_turbo) (1 = off)"
grep -qw svm /proc/cpuinfo || grep -qw vmx /proc/cpuinfo || \
  echo "WARNING: virtualization (SVM/VT-x) is disabled in BIOS."
exit 0
