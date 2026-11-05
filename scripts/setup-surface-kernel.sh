#!/bin/bash
# ==============================================================================
# Helper Script: Kernel Staging and Akmods Builder for Surface Image
# Executed during container build / BlueBuild recipe execution
# ==============================================================================

set -euo pipefail

echo ">>> Configuring Surface Book 2 kernel environment and systemd units..."

# Set executable permissions on utility scripts
chmod 0755 /usr/local/bin/surface-nvidia-power-limit.sh || true
chmod 0755 /usr/local/bin/disable-bd-prochot.sh || true
chmod 0755 /usr/local/bin/surface-firstboot.sh || true

# Autoload msr module at boot
mkdir -p /etc/modules-load.d
echo "msr" > /etc/modules-load.d/msr.conf

# Install throttled from official upstream git repository
if [ ! -d /opt/throttled ]; then
    echo ">>> Installing throttled from upstream git..."
    rm -rf /tmp/throttled
    git clone https://github.com/erpalma/throttled.git /tmp/throttled
    cd /tmp/throttled
    ./install.sh --init systemd --no-start
    rm -rf /tmp/throttled
fi

# Rebuild NVIDIA kernel module against the Surface kernel if akmods is present
if command -v akmods &>/dev/null; then
    KVER=$(rpm -qa --qf "%{VERSION}-%{RELEASE}.%{ARCH}\n" kernel-surface | head -n1 || true)
    if [ -n "$KVER" ]; then
        echo ">>> Compiling akmod-nvidia against installed kernel-surface ($KVER)..."
        akmods --force --kernels "$KVER" || echo ">>> Note: akmods will complete module compilation on first boot."
        dracut --force --kver "$KVER" || true
    fi
fi

# Enable critical systemd units
systemctl enable iptsd.service || true
systemctl enable surface-dtx-daemon.service || true
systemctl enable throttled.service || true
systemctl enable surface-nvidia-power-limit.service || true
systemctl enable surface-bdprochot-fallback.service || true
systemctl enable surface-firstboot.service || true

# Ensure Flathub repository is pre-configured
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

echo ">>> Surface kernel staging completed successfully."
