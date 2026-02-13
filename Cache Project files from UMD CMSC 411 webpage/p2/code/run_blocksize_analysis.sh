#!/usr/bin/env bash

# --- Fixed Configuration ---
SIM_EXEC="./sim" 
LOG_DIR="log_blocksize_analysis" 
CACHE_SIZE=8192   # 8 KB for I and D
ASSOC=2           # 2-way associative
POLICY="-wb -wa"  # Fixed Write-Back and Write-Allocate

# --- Experiment Parameters ---
# Block Sizes: 4B to 4KB in powers of 2
BLOCK_SIZES=(4 8 16 32 64 128 256 512 1024 2048 4096)
TRACES=("../traces/cc.trace" "../traces/spice.trace" "../traces/tex.trace")

# -------------------------------------------------

echo "Starting Block Size Analysis (Fixed 8KB, 2-way, WB/WA)..."
echo "----------------------------------------------------------------"

mkdir -p "${LOG_DIR}"

# 1. Loop through all three traces
for TRACE_PATH in "${TRACES[@]}"; do
    TRACE_NAME=$(basename "$TRACE_PATH" .trace)
    
    # 2. Loop through all Block Sizes
    for BS in "${BLOCK_SIZES[@]}"; do
        
        # --- Construct Log File Name ---
        LOG_FILE="${LOG_DIR}/Trace_${TRACE_NAME}_BS${BS}.log"
        
        echo "Running: Trace=${TRACE_NAME}, BS=${BS}B..."
        
        # --- The Simulation Command ---
        $SIM_EXEC -is ${CACHE_SIZE} -ds ${CACHE_SIZE} -bs ${BS} -a ${ASSOC} ${POLICY} ${TRACE_PATH} > ${LOG_FILE}

        # Check for error
        if [ $? -ne 0 ]; then
            echo "Error: Simulation failed for ${TRACE_NAME} at BS=${BS}B. Stopping."
            exit 1
        fi
        
    done
done

echo "=================================================================="
echo "Analysis complete. Results are in '${LOG_DIR}'."
echo "=================================================================="