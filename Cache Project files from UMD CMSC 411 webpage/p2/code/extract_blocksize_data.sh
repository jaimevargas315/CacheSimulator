#!/usr/bin/env bash

# This script collects I-Cache and D-Cache Hit Rates from the Block Size analysis logs.
LOG_DIR="log_blocksize_analysis"
OUTPUT_FILE="block_size_results.txt"

if [ ! -d "$LOG_DIR" ]; then
    echo "Error: Log directory not found: '$LOG_DIR'"
    exit 1
fi

echo "--- Block Size Analysis Results (Fixed 8KB, 2-way, WB/WA) ---" > $OUTPUT_FILE
echo "Block Size (B) | Trace | I-Cache Hit Rate | D-Cache Hit Rate" >> $OUTPUT_FILE
echo "----------------------------------------------------------" >> $OUTPUT_FILE

# Loop through all log files generated
for log_file in "${LOG_DIR}"/Trace_*.log; do
    
    # 1. Extract parameters from the filename (e.g., Trace_cc_BS64.log)
    FILENAME=$(basename "$log_file")
    TRACE_NAME=$(echo "$FILENAME" | sed -E 's/Trace_([a-z]+)_BS.*$/\1/')
    BS=$(echo "$FILENAME" | sed -E 's/.*BS([0-9]+)\.log/\1/')
    
    # 2. Extract Hit Rates using grep to find the pattern (0.xxxx)
    # assume the output format is: "DATA/INSTRUCTIONS: total misses: XX (hit rate: 0.XXXX)"
    
    # Find the line starting with "INSTRUCTIONS" and use grep -oP to extract the number inside the parentheses.
    I_HIT_RATE=$(grep 'INSTRUCTIONS' -A3 "$log_file" | tail -1 | grep -oP '\d\.\d+' | head -1)
    
    # Find the line starting with "DATA" and use grep -oP to extract the number inside the parentheses.
    D_HIT_RATE=$(grep 'DATA' -A3 "$log_file" | tail -1 | grep -oP '\d\.\d+' | head -1)

    # Use a placeholder if extraction failed to prevent empty fields
    I_HIT_RATE=${I_HIT_RATE:-"N/A"}
    D_HIT_RATE=${D_HIT_RATE:-"N/A"}
    
    # 3. Print results (formatted to match the header)
    printf "%-14s | %-5s | %-16s | %-16s\n" \
        "$BS" "$TRACE_NAME" "$I_HIT_RATE" "$D_HIT_RATE" >> $OUTPUT_FILE
done

echo "----------------------------------------------------------" >> $OUTPUT_FILE
echo "Extraction complete. Results saved to $OUTPUT_FILE"