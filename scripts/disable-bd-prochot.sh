#!/bin/bash
# ==============================================================================
# Surface Book 2 - Direct MSR 0x1FC BDPROCHOT Hardware Mitigation
# Disables bit 0 of MSR 0x1FC to instantly unlock the 400 MHz CPU lockup
# triggered by missing or 0% dead battery telemetry from the Embedded Controller.
# ==============================================================================

set -euo pipefail

echo "[BDPROCHOT Mitigator] Initializing direct CPU MSR override..."

# Ensure MSR kernel module is loaded
modprobe msr 2>/dev/null || true

# Verify rdmsr and wrmsr availability (from msr-tools)
if ! command -v rdmsr &>/dev/null || ! command -v wrmsr &>/dev/null; then
    echo "[BDPROCHOT Mitigator] msr-tools utilities not found. Skipping direct register write."
    exit 0
fi

NUM_CORES=$(nproc)
echo "[BDPROCHOT Mitigator] Iterating over $NUM_CORES CPU logical cores..."

CLEARED_COUNT=0
for (( c=0; c<NUM_CORES; c++ )); do
    # Read current MSR 0x1FC value in hex
    CURRENT_HEX=$(rdmsr -p "$c" 0x1FC 2>/dev/null || true)
    if [ -n "$CURRENT_HEX" ]; then
        # Parse hex and test bit 0 (BDPROCHOT)
        CURRENT_DEC=$(( 0x$CURRENT_HEX ))
        if [ $(( CURRENT_DEC & 1 )) -eq 1 ]; then
            # Bit 0 is asserted: clear it
            NEW_DEC=$(( CURRENT_DEC & ~1 ))
            wrmsr -p "$c" 0x1FC "$NEW_DEC" 2>/dev/null || true
            CLEARED_COUNT=$(( CLEARED_COUNT + 1 ))
        fi
    fi
done

echo "[BDPROCHOT Mitigator] BDPROCHOT cleared across $CLEARED_COUNT cores (out of $NUM_CORES)."
echo "[BDPROCHOT Mitigator] CPU freed from 400 MHz throttle state."
exit 0
