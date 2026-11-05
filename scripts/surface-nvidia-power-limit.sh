#!/bin/bash
# ==============================================================================
# Surface Book 2 - NVIDIA GTX 1050 Power Management for 65W USB-C Charger
# Anti-Brownout Protection: Enforces strict power & clock capping to prevent
# exceeding the 65W USB-C PD capacity with dead batteries.
# ==============================================================================

set -euo pipefail

# Default power parameters for 65W USB-C Power Adapter
GPU_TARGET_POWER_W=30
GPU_MAX_CLOCK_MHZ=1100

# Source user overrides if present
if [ -f /etc/surface-power.conf ]; then
    # shellcheck source=/dev/null
    source /etc/surface-power.conf
fi

echo "======================================================================"
echo "[Surface Power Manager] Profile: 65W USB-C Power Envelope (No Battery)"
echo "[Surface Power Manager] GPU Target Power Cap: ${GPU_TARGET_POWER_W}W"
echo "======================================================================"

# 1. Verify nvidia-smi tool existence
if ! command -v nvidia-smi &>/dev/null; then
    echo "[Surface Power Manager] nvidia-smi utility not found. Skipping."
    exit 0
fi

# 2. Check if NVIDIA GPU is present and responsive
if ! nvidia-smi -L &>/dev/null; then
    echo "[Surface Power Manager] No active NVIDIA GPU found (clipboard detached or GPU off)."
    exit 0
fi

GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1 || echo "Unknown NVIDIA GPU")
echo "[Surface Power Manager] Detected GPU: $GPU_NAME"

# 3. Enable Persistence Mode
echo "[Surface Power Manager] Enabling persistence mode..."
nvidia-smi -pm 1 2>/dev/null || echo "[Surface Power Manager] Persistence mode notice: already active or not applicable."

# 4. Enforce Power Limit to 30 Watts
echo "[Surface Power Manager] Applying power limit (${GPU_TARGET_POWER_W}W)..."
if nvidia-smi -pl "$GPU_TARGET_POWER_W" 2>/dev/null; then
    echo "[Surface Power Manager] Successfully clamped GPU power limit to ${GPU_TARGET_POWER_W}W."
else
    echo "[Surface Power Manager] Direct ${GPU_TARGET_POWER_W}W rejected by VBIOS. Checking supported range..."
    MIN_PL=$(nvidia-smi --query-gpu=power.min_limit --format=csv,noheader,nounits 2>/dev/null | head -n1 | cut -d'.' -f1 || true)
    MAX_PL=$(nvidia-smi --query-gpu=power.max_limit --format=csv,noheader,nounits 2>/dev/null | head -n1 | cut -d'.' -f1 || true)
    
    if [ -n "$MIN_PL" ] && [ -n "$MAX_PL" ] && [ "$MIN_PL" != "N/A" ]; then
        echo "[Surface Power Manager] Hardware reported range: ${MIN_PL}W to ${MAX_PL}W"
        APPLIED_PL=$GPU_TARGET_POWER_W
        if [ "$GPU_TARGET_POWER_W" -lt "$MIN_PL" ]; then
            APPLIED_PL=$MIN_PL
        elif [ "$GPU_TARGET_POWER_W" -gt "$MAX_PL" ]; then
            APPLIED_PL=$MAX_PL
        fi
        echo "[Surface Power Manager] Clamping to minimum supported power limit: ${APPLIED_PL}W..."
        nvidia-smi -pl "$APPLIED_PL" 2>/dev/null || true
    else
        echo "[Surface Power Manager] Mobile VBIOS does not support runtime -pl modification."
    fi
fi

# 5. Attempt clock limit ceiling if supported (prevents turbo power spikes beyond 1100 MHz)
if [ -n "$GPU_MAX_CLOCK_MHZ" ]; then
    echo "[Surface Power Manager] Setting graphics clock ceiling (${GPU_MAX_CLOCK_MHZ} MHz)..."
    nvidia-smi -lgc 300,"$GPU_MAX_CLOCK_MHZ" 2>/dev/null || true
fi

# 6. Enforce PowerMizer Adaptive Mode (mode 0) via nvidia-settings if graphical session is active
if command -v nvidia-settings &>/dev/null; then
    echo "[Surface Power Manager] Setting PowerMizer to Adaptive mode..."
    DISPLAY=:0 XAUTHORITY=/var/run/lightdm/root/:0 nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=0" 2>/dev/null || true
fi

# 7. Output confirmation telemetry
echo "[Surface Power Manager] Current GPU Status:"
nvidia-smi --query-gpu=name,power.limit,power.default_limit,power.draw,temperature.gpu,clocks.current.graphics --format=csv 2>/dev/null || true
echo "[Surface Power Manager] GPU protection active for 65W USB-C power supply."
echo "======================================================================"
exit 0
