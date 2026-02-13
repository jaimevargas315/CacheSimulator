#!/usr/bin/env bash

# This script collects I-Cache and D-Cache Hit Rates from the Associativity analysis logs.
LOG_DIR="log_assoc_analysis"
OUTPUT_FILE="associativity_results.txt"

if [ ! -d "$LOG_DIR" ]; then
    echo "Error: Log directory not found: '$LOG_DIR'"
    exit 1
fi

echo "--- Associativity Analysis Results (Fixed 8KB, 128B BS, WB/WA) ---" > $OUTPUT_FILE
echo "Associativity | Trace | I-Cache Hit Rate | D-Cache Hit Rate" >> $OUTPUT_FILE
echo "----------------------------------------------------------" >> $OUTPUT_FILE

# Loop through all log files generated
for log_file in "${LOG_DIR}"/Trace_*.log; do
    
    # 1. Extract parameters from the filename (e.g., Trace_cc_A4.log)
    FILENAME=$(basename "$log_file")
    TRACE_NAME=$(echo "$FILENAME" | sed -E 's/Trace_([a-z]+)_A.*$/\1/')
    ASSOC=$(echo "$FILENAME" | sed -E 's/.*A([0-9]+)\.log/\1/')
    
    # 2. Extract Hit Rates using the robust pattern extraction
    I_HIT_RATE=$(grep 'INSTRUCTIONS' -A3 "$log_file" | tail -1 | grep -oP '\d\.\d+' | head -1)
    D_HIT_RATE=$(grep 'DATA' -A3 "$log_file" | tail -1 | grep -oP '\d\.\d+' | head -1)

    # Use a placeholder if extraction failed
    I_HIT_RATE=${I_HIT_RATE:-"N/A"}
    D_HIT_RATE=${D_HIT_RATE:-"N/A"}
    
    # 3. Print results (formatted to match the header)
    printf "%-13s | %-5s | %-16s | %-16s\n" \
        "$ASSOC" "$TRACE_NAME" "$I_HIT_RATE" "$D_HIT_RATE" >> $OUTPUT_FILE
done

echo "----------------------------------------------------------" >> $OUTPUT_FILE
echo "Extraction complete. Results saved to $OUTPUT_FILE"