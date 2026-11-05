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

# Ensure EFI vendor tree is populated for bootc-image-builder
mkdir -p /boot/efi/EFI/fedora /boot/efi/EFI/BOOT /usr/lib/efi/shim/EFI/fedora
cp -r /boot/efi/EFI/fedora/* /usr/lib/efi/shim/EFI/fedora/ 2>/dev/null || true

# Ensure /usr/bin/dnf is accessible for bootc-image-builder
if [ ! -e /usr/bin/dnf ] && [ -e /usr/bin/dnf5 ]; then
    echo ">>> Linking /usr/bin/dnf5 to /usr/bin/dnf for bootc manifest compatibility..."
    ln -sf /usr/bin/dnf5 /usr/bin/dnf
fi

# Install throttled cleanly into /usr/lib/throttled (Atomic/OSTree safe: avoids /opt symlink issues)
if [ ! -d /usr/lib/throttled/venv ]; then
    echo ">>> Installing throttled from upstream git into /usr/lib/throttled..."
    mkdir -p /usr/lib/throttled
    python3 -m venv --system-site-packages /usr/lib/throttled/venv
    /usr/lib/throttled/venv/bin/pip install --no-cache-dir git+https://github.com/erpalma/throttled.git
    ln -sf /usr/lib/throttled/venv/bin/throttled /usr/local/bin/throttled || true
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
