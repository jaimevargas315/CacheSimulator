#!/usr/bin/env bash

LOG_DIR="log_size_analysis"

# Check if the log directory exists
if [ ! -d "$LOG_DIR" ]; then
    echo "Error: Log directory not found: '$LOG_DIR'"
    echo "Please ensure you have run the simulation script first."
    exit 1
fi

# 1. Find all unique trace prefixes (e.g., cc, spice, tex) in the log folder
# We look for the pattern: [prefix]_size_*.log
# And extract the [prefix] part.
TRACES=$(find "$LOG_DIR" -maxdepth 1 -type f -name '*_size_*.log' | 
         sed -E 's/.*\/([a-z]+)_size_[0-9]+B\.log/\1/' | 
         sort -u)

if [ -z "$TRACES" ]; then
    echo "Error: No log files found in '$LOG_DIR' matching the pattern [prefix]_size_[size]B.log."
    exit 1
fi

# 2. Loop through each unique trace type found
for TRACE_PREFIX in $TRACES; do

    echo "================================================"
    echo "--- Results for Trace: ${TRACE_PREFIX} ---"
    echo "================================================"
    echo "Cache Size (B) | I-Cache Hit Rate | D-Cache Hit Rate"
    echo "------------------------------------------------------"

    # 3. Loop through all log files for the current prefix, sorting them numerically by size
    find "$LOG_DIR" -maxdepth 1 -type f -name "${TRACE_PREFIX}_size_*.log" | 
    sort -V | # Sorts the files numerically (4B before 16B)
    while read -r log_file; do
        
        # Extract cache size from the filename (e.g., cc_size_4B.log -> 4)
        # Use basename and sed to isolate the size number
        size=$(basename "$log_file" | sed -E 's/.*_size_([0-9]+)B\.log/\1/')
        
        # Extract Instruction Hit Rate
        i_hit_rate=$(grep -A3 'INSTRUCTIONS' "$log_file" | tail -1 | awk '{print $NF}' | tr -d ')')
        
        # Extract Data Hit Rate
        d_hit_rate=$(grep -A3 'DATA' "$log_file" | tail -1 | awk '{print $NF}' | tr -d ')')

        # Print results formatted neatly
        printf "%14s | %16s | %16s\n" "$size" "$i_hit_rate" "$d_hit_rate"
    done
    echo "" # Add a newline separator after each trace table
done

echo "Extraction complete."