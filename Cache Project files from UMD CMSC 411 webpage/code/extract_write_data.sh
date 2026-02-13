#!/usr/bin/env bash

# This script assumes it is run from the 'code' directory where logs were created.
LOG_DIR="log_write_analysis"

if [ ! -d "$LOG_DIR" ]; then
    echo "Error: Log directory not found: '$LOG_DIR'"
    echo "Please ensure the simulation script has run successfully and created the '$LOG_DIR' folder."
    exit 1
fi

echo "--- Write Policy Analysis Results (Memory Traffic Comparison) ---"
echo "Trace: spice.trace (Write No Allocate Policy)"
echo "----------------------------------------------------------------------------------------------------------------------"
printf "%-5s | %-5s | %-6s | %-7s | %-7s | %-12s | %-12s | %-12s\n" \
       "Size" "BS" "ASSOC" "Policy" "D-Hit%" "Demand Fetch" "Copies Back" "TOTAL TRAFFIC"
echo "----------------------------------------------------------------------------------------------------------------------"

# Loop through all log files generated, sorting them alphabetically by file name for order
for log_file in "${LOG_DIR}"/*.log; do
    
    # 1. Extract parameters from the filename (e.g., C8192B_BS64_A2_WB.log)
    FILENAME=$(basename "$log_file")
    
    # Extract Size (e.g., 8192 from C8192B)
    SIZE=$(echo "$FILENAME" | sed -E 's/C([0-9]+)B_.*$/\1/')
    # Extract Block Size (e.g., 64 from BS64)
    BS=$(echo "$FILENAME" | sed -E 's/.*BS([0-9]+)_.*$/\1/')
    # Extract Associativity (e.g., 2 from A2)
    ASSOC=$(echo "$FILENAME" | sed -E 's/.*A([0-9]+)_.*$/\1/')
    # Extract Policy (e.g., WB from _WB.log)
    POLICY=$(echo "$FILENAME" | sed -E 's/.*_([A-Z]+)\.log/\1/')
    
    # 2. Extract statistics from the log file
    
    # Extract Data Hit Rate (the most relevant metric for write policy comparison)
    # Searches for 'DATA', pulls the line with hit rate, and extracts the last number
    D_HIT_RATE=$(grep -A3 'DATA' "$log_file" | tail -1 | awk '{print $NF}' | tr -d ')')

    # Traffic Metrics (Total traffic for both I and D cache combined)
    # 'demand fetch' and 'copies back' are at the very end of the output.
    DEMAND_FETCH_LINE=$(grep 'demand fetch:' "$log_file")
    COPIES_BACK_LINE=$(grep 'copies back:' "$log_file")
    
    DEMAND_FETCH=$(echo "$DEMAND_FETCH_LINE" | awk '{print $3}')
    COPIES_BACK=$(echo "$COPIES_BACK_LINE" | awk '{print $3}')
    
    # Calculate Total Traffic (in words)
    TOTAL_TRAFFIC=$(( DEMAND_FETCH + COPIES_BACK ))

    # 3. Print results formatted neatly
    printf "%-5s | %-5s | %-6s | %-7s | %-7s | %-12s | %-12s | %-12s\n" \
        "$SIZE" "$BS" "$ASSOC" "$POLICY" "$D_HIT_RATE" \
        "$DEMAND_FETCH" "$COPIES_BACK" "$TOTAL_TRAFFIC"
done

echo "----------------------------------------------------------------------------------------------------------------------"