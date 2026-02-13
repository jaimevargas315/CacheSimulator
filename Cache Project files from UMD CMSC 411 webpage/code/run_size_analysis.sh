#!/usr/bin/env bash

# --- Configuration ---
SIM_EXEC="./sim"
TRACE_FILE="$1"
LOG_DIR="log_traffic_analysis"
# ---------------------

echo "Starting Memory Traffic Comparison (Write-Through vs. Write-Back)..."
echo "Trace File: ${TRACE_FILE}"
echo "Log Directory: ${LOG_DIR}"
echo "----------------------------------------------------------------"

# Check if the trace file exists
if [ ! -f "$TRACE_FILE" ]; then
    echo "Error: Trace file not found at '$TRACE_FILE'"
    exit 1
fi

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# --- Define the simulation configurations ---
# Format: "SIZE_KB BLOCK_SIZE ASSOCIATIVITY POLICY_FLAG"
CONFIGS=(
    "8192 64 2 -wt"    # Run 1: 8KB, 64B, 2-way, Write-Through
    "8192 64 2 -wb"    # Run 2: 8KB, 64B, 2-way, Write-Back
    "16384 128 4 -wt"  # Run 3: 16KB, 128B, 4-way, Write-Through
    "16384 128 4 -wb"  # Run 4: 16KB, 128B, 4-way, Write-Back
    "8192 128 4 -wt"   # Run 5: 8KB, 128B, 4-way, Write-Through (Bonus)
)

# Fixed Allocation Policy for all runs: Write-No-Allocate
ALLOC_POLICY="-nw"

for config in "${CONFIGS[@]}"; do
    # Read configuration values from the string
    read SIZE BS ASSOC POLICY <<< "$config"
    
    # Extract short policy name for log file
    if [ "$POLICY" = "-wt" ]; then
        POLICY_NAME="WT"
    else
        POLICY_NAME="WB"
    fi
    
    # Output log file name: traffic_C8K_B64_A2_WT.log
    LOG_FILE="${LOG_DIR}/traffic_C$((SIZE/1024))K_B${BS}_A${ASSOC}_${POLICY_NAME}.log"

    echo "Running C=$((SIZE/1024))KB, BS=${BS}, A=${ASSOC}, Policy=${POLICY_NAME}..."

    # --- The Simulation Command ---
    # -is $SIZE -ds $SIZE (Split I/D Cache Size)
    # -bs $BS (Block Size)
    # -a $ASSOC (Associativity)
    # $POLICY (Write Policy: -wt or -wb)
    # $ALLOC_POLICY (Allocation Policy: -nw)
    
    $SIM_EXEC -is ${SIZE} -ds ${SIZE} -bs ${BS} -a ${ASSOC} ${POLICY} ${ALLOC_POLICY} "${TRACE_FILE}" > "${LOG_FILE}"

    # Check if the simulator ran successfully
    if [ $? -ne 0 ]; then
        echo "Error: Simulation failed for Policy ${POLICY_NAME} at C=${SIZE}B. Stopping."
        exit 1
    fi
done

echo "----------------------------------------------------------------"
echo "Analysis complete. Results stored in the '${LOG_DIR}' directory."
echo "Look for the 'Total traffic' line in the log files to compare policies."