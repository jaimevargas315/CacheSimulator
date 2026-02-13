#!/usr/bin/env bash

# --- Fixed Configuration ---
SIM_EXEC="./sim" 
TRACE_PATH="../traces/spice.trace" # Using spice.trace as a default
LOG_DIR="log_alloc_analysis"       # New log directory for clear separation
FIXED_WRITE_POLICY="-wb"           # FIXED: Write Back
RUN_COUNTER=0
MAX_RUNS=5

# --- Experiment Parameters (Same as previous run) ---
CACHE_SIZES=(8192 16384) 
BLOCK_SIZES=(64 128)
ASSOCIATIVITIES=(2 4)

# --- Policies to Compare ---
# Policies to compare: Write Allocate (-wa) and Write No Allocate (-nw)
ALLOC_POLICIES=("-wa" "-nw")

# -------------------------------------------------

echo "Starting Write Allocation Policy Analysis (WA vs. WNA)..."
echo "Fixed Write Policy: WRITE BACK"
echo "Trace: ${TRACE_PATH}"
echo "----------------------------------------------------------------"

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# 1. Loop through all Cache Sizes
for SIZE in "${CACHE_SIZES[@]}"; do
    # 2. Loop through all Block Sizes
    for BS in "${BLOCK_SIZES[@]}"; do
        # 3. Loop through all Associativities
        for ASSOC in "${ASSOCIATIVITIES[@]}"; do
            # 4. Loop through both Allocation Policies
            for ALLOC_POLICY in "${ALLOC_POLICIES[@]}"; do
                
                # Check if we've hit the max run limit
                if [ $RUN_COUNTER -ge $MAX_RUNS ]; then
                    break 4 # Break out of all four loops
                fi

                # Extract policy name for log file
                if [ "$ALLOC_POLICY" == "-wa" ]; then
                    POLICY_NAME="WA"
                else
                    POLICY_NAME="WNA"
                fi

                # --- Construct Log File Name ---
                LOG_FILE="${LOG_DIR}/C${SIZE}B_BS${BS}_A${ASSOC}_${POLICY_NAME}.log"
                
                echo "Running: C=${SIZE}B, BS=${BS}, A=${ASSOC}, Policy=${POLICY_NAME}..."
                
                # --- The Simulation Command ---
                # Fixed Write Policy: $FIXED_WRITE_POLICY (-wb)
                # Looping Allocation Policy: $ALLOC_POLICY (-wa or -nw)
                $SIM_EXEC -is ${SIZE} -ds ${SIZE} -bs ${BS} -a ${ASSOC} ${FIXED_WRITE_POLICY} ${ALLOC_POLICY} ${TRACE_PATH} > ${LOG_FILE}

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