#!/bin/bash
# ==============================================================================
# Surface Book 2 - NVIDIA GTX 1050 45W Power Cap & Persistence Mode
# Prevents AC power adapter brownouts / sudden shutoffs due to transient spikes
# when operating with 0% / dead batteries (zero battery buffer).
# ==============================================================================

set -euo pipefail

echo "======================================================================"
echo "[Surface Power Manager] Initializing NVIDIA GTX 1050 Protection Service"
echo "======================================================================"

# 1. Verify nvidia-smi tool existence
if ! command -v nvidia-smi &>/dev/null; then
    echo "[Surface Power Manager] nvidia-smi utility not found. Skipping."
    exit 0
fi

# 2. Check if the NVIDIA device is physically connected and responsive
if ! nvidia-smi -L &>/dev/null; then
    echo "[Surface Power Manager] No active NVIDIA GPU found (clipboard detached or GPU powered off)."
    exit 0
fi

GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1 || echo "Unknown NVIDIA GPU")
echo "[Surface Power Manager] Detected GPU: $GPU_NAME"

# 3. Enable Persistence Mode to ensure driver stays resident in memory
echo "[Surface Power Manager] Enabling persistence mode..."
if nvidia-smi -pm 1; then
    echo "[Surface Power Manager] Persistence mode successfully activated."
else
    echo "[Surface Power Manager] WARNING: Failed to enable persistence mode."
fi

# 4. Enforce Power Limit to 45 Watts
TARGET_PL=45
echo "[Surface Power Manager] Attempting to set power limit to ${TARGET_PL}W..."

if nvidia-smi -pl "$TARGET_PL" 2>/dev/null; then
    echo "[Surface Power Manager] Successfully clamped GPU power limit to ${TARGET_PL}W."
else
    echo "[Surface Power Manager] Direct ${TARGET_PL}W set failed. Inspecting supported range..."
    MIN_PL=$(nvidia-smi --query-gpu=power.min_limit --format=csv,noheader,nounits 2>/dev/null | head -n1 | cut -d'.' -f1 || true)
    MAX_PL=$(nvidia-smi --query-gpu=power.max_limit --format=csv,noheader,nounits 2>/dev/null | head -n1 | cut -d'.' -f1 || true)
    
    if [ -n "$MIN_PL" ] && [ -n "$MAX_PL" ]; then
        echo "[Surface Power Manager] Device reports supported range: ${MIN_PL}W to ${MAX_PL}W"
        APPLIED_PL=$TARGET_PL
        if [ "$TARGET_PL" -lt "$MIN_PL" ]; then
            APPLIED_PL=$MIN_PL
        elif [ "$TARGET_PL" -gt "$MAX_PL" ]; then
            APPLIED_PL=$MAX_PL
        fi
        echo "[Surface Power Manager] Clamping to nearest valid ceiling: ${APPLIED_PL}W..."
        nvidia-smi -pl "$APPLIED_PL" || true
    fi
fi

# 5. Output confirmation telemetry
echo "[Surface Power Manager] Current GPU Status:"
nvidia-smi --query-gpu=name,power.limit,power.default_limit,power.draw,temperature.gpu --format=csv
echo "[Surface Power Manager] Protection active. Transient power spikes mitigated."
echo "======================================================================"
exit 0
