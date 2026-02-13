#!/usr/bin/env bash

# --- Fixed Configuration ---
SIM_EXEC="./sim" 
LOG_DIR="log_assoc_analysis" 
CACHE_SIZE=8192   # 8 KB for I and D
BLOCK_SIZE=128    # 128 B fixed block size
POLICY="-wb -wa"  # Fixed Write-Back and Write-Allocate

# --- Experiment Parameters ---
# Associativities: 1-way (direct-mapped) to 64-way (fully associative) in powers of 2
ASSOCIATIVITIES=(1 2 4 8 16 32 64)
TRACES=("../traces/cc.trace" "../traces/spice.trace" "../traces/tex.trace")

# -------------------------------------------------

echo "Starting Associativity Analysis (Fixed 8KB, 128B BS, WB/WA)..."
echo "----------------------------------------------------------------"

mkdir -p "${LOG_DIR}"

# 1. Loop through all three traces
for TRACE_PATH in "${TRACES[@]}"; do
    TRACE_NAME=$(basename "$TRACE_PATH" .trace)
    
    # 2. Loop through all Associativities
    for ASSOC in "${ASSOCIATIVITIES[@]}"; do
        
        # --- Construct Log File Name ---
        LOG_FILE="${LOG_DIR}/Trace_${TRACE_NAME}_A${ASSOC}.log"
        
        echo "Running: Trace=${TRACE_NAME}, Associativity=${ASSOC}..."
        
        # --- The Simulation Command ---
        $SIM_EXEC -is ${CACHE_SIZE} -ds ${CACHE_SIZE} -bs ${BLOCK_SIZE} -a ${ASSOC} ${POLICY} ${TRACE_PATH} > ${LOG_FILE}

        # Check for error
        if [ $? -ne 0 ]; then
            echo "Error: Simulation failed for ${TRACE_NAME} at A=${ASSOC}. Stopping."
            exit 1
        fi
        
    done
done

echo "=================================================================="
echo "Analysis complete. Results are in '${LOG_DIR}'."
echo "=================================================================="