#!/usr/bin/env bash

# --- Fixed Configuration ---
SIM_EXEC="./sim" 
TRACE_PATH="../traces/spice.trace" # Using spice.trace as a default
LOG_DIR="log_write_analysis"

# --- Experiment Parameters ---
# Cache Sizes (IS=DS) in bytes: 8K and 16K
# 8KB = 8192, 16KB = 16384
CACHE_SIZES=(8192 16384) 

# Block Sizes in bytes: 64 and 128
BLOCK_SIZES=(64 128)

# Associativities: 2 and 4
ASSOCIATIVITIES=(2 4)

# --- Fixed Policies for Comparison ---
# Write Allocate Policy: always Write No Allocate (-nw)
ALLOC_POLICY="-nw" 
# The policies we are comparing: Write Back (-wb) and Write Through (-wt)
WRITE_POLICIES=("-wb" "-wt")

# -------------------------------------------------

echo "Starting Write Policy Analysis (Write-Through vs. Write-Back)..."
echo "Fixed Trace: ${TRACE_PATH}"
echo "----------------------------------------------------------------"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Run counter to stop after 5 simulations (or adjust to run all combinations)
RUN_COUNTER=0
MAX_RUNS=5

# 1. Loop through all Cache Sizes
for SIZE in "${CACHE_SIZES[@]}"; do
    # 2. Loop through all Block Sizes
    for BS in "${BLOCK_SIZES[@]}"; do
        # 3. Loop through all Associativities
        for ASSOC in "${ASSOCIATIVITIES[@]}"; do
            # 4. Loop through both Write Policies
            for POLICY in "${WRITE_POLICIES[@]}"; do
                
                # Check if we've hit the max run limit
                if [ $RUN_COUNTER -ge $MAX_RUNS ]; then
                    break 4 # Break out of all four loops
                fi

                # Extract policy name for log file
                if [ "$POLICY" == "-wb" ]; then
                    POLICY_NAME="WB"
                else
                    POLICY_NAME="WT"
                fi

                # --- Construct Log File Name ---
                LOG_FILE="${LOG_DIR}/C${SIZE}B_BS${BS}_A${ASSOC}_${POLICY_NAME}.log"
                
                echo "Running: C=${SIZE}B, BS=${BS}, A=${ASSOC}, Policy=${POLICY_NAME}..."
                
                # --- The Simulation Command ---
                # NOTE: Using split I/D cache (-is $SIZE -ds $SIZE)
                $SIM_EXEC -is ${SIZE} -ds ${SIZE} -bs ${BS} -a ${ASSOC} ${POLICY} ${ALLOC_POLICY} ${TRACE_PATH} > ${LOG_FILE}

                # Check for error
                if [ $? -ne 0 ]; then
                    echo "Error: Simulation failed for ${POLICY_NAME} at C=${SIZE}B. Stopping."
                    exit 1
                fi
                
                RUN_COUNTER=$((RUN_COUNTER + 1))
            done
        done
    done
done

echo "=================================================================="
echo "Analysis complete (${RUN_COUNTER} runs). Results are in '${LOG_DIR}'."
echo "=================================================================="