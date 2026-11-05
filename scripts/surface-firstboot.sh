#!/bin/bash
# ==============================================================================
# First-Boot Provisioning Script for Microsoft Surface Book 2
# Ensures Flatpak applications (LocalSend, Deskflow) are installed on first boot
# ==============================================================================

set -euo pipefail

echo "======================================================================"
echo "[Surface First-Boot] Starting first-boot application provisioning..."
echo "======================================================================"

# Ensure flathub repository is registered system-wide
echo "[Surface First-Boot] Ensuring Flathub remote is configured..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true

# Wait for internet connectivity (up to 30 attempts, 2s sleep)
echo "[Surface First-Boot] Checking internet connectivity for application download..."
CONNECTED=0
for i in {1..30}; do
    if curl -s --head --request GET https://dl.flathub.org/repo/ | grep -q "200\|301\|302\|403"; then
        echo "[Surface First-Boot] Network reachable on attempt $i."
        CONNECTED=1
        break
    fi
    sleep 2
done

if [ "$CONNECTED" -eq 1 ]; then
    # Install LocalSend Flatpak
    if ! flatpak info org.localsend.localsend_app &>/dev/null; then
        echo "[Surface First-Boot] Installing LocalSend (org.localsend.localsend_app)..."
        flatpak install -y --system flathub org.localsend.localsend_app || true
    else
        echo "[Surface First-Boot] LocalSend is already installed."
    fi

    # Install Deskflow Flatpak (if not already installed via RPM)
    if ! command -v deskflow &>/dev/null && ! flatpak info org.deskflow.Deskflow &>/dev/null; then
        echo "[Surface First-Boot] Installing Deskflow Flatpak..."
        flatpak install -y --system flathub org.deskflow.Deskflow || true
    fi

    echo "[Surface First-Boot] Flatpak provisioning finished successfully."
    # Disable service so it does not run again
    systemctl disable surface-firstboot.service || true
else
    echo "[Surface First-Boot] Network not reachable. Will retry on next boot."
fi

echo "======================================================================"
exit 0
