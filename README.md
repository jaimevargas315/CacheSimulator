# Configurable Cache Simulator

This C-based simulator models the behavior of a CPU cache hierarchy. It allows for the evaluation of different cache architectures (Unified vs. Split), associativity levels, and memory consistency policies by processing memory access traces.

---

## Architecture Overview

The simulator translates memory addresses into **Tag**, **Index**, and **Offset** to manage data placement and retrieval within the simulated environment.



### Core Components
* **Flexible Organization:** Supports **Unified** (Instructions and Data in one cache) or **Split** (Harvard architecture with separate I-cache and D-cache) configurations.
* **LRU Replacement Policy:** Each set is managed as a doubly-linked list. The "Head" is the Most Recently Used (MRU) block, and the "Tail" is the Least Recently Used (LRU) block, which is the first candidate for eviction.
* **Statistics Engine:** Tracks accesses, misses (cold, conflict, and capacity), replacements, and total memory traffic.

---

## Configuration Parameters

The behavior of the simulation is defined by several key parameters:

| Parameter | Functionality |
| :--- | :--- |
| **Block Size** | Sets the size of each cache line (must be a power of 2). |
| **Associativity** | Supports Direct-Mapped ($1$-way), Set-Associative ($N$-way), or Fully Associative. |
| **Write Policy** | Choose between **Write-Back** (update memory only on eviction) or **Write-Through** (immediate memory update). |
| **Allocation Policy** | Choose **Write-Allocate** (fetch on write miss) or **No-Write-Allocate** (bypass cache on write miss). |



---

## Algorithmic Logic

### 1. Address Deconstruction
For every memory access, the simulator calculates the specific location within the cache:
* **Index Offset:** Calculated as $\log_2(\text{Block Size})$.
* **Set Index:** Extracted from the address to determine which row of the cache to search.
* **Tag:** The remaining bits used to verify if the cached block matches the requested address.

### 2. The Access Cycle (`perform_access`)
1.  **Search:** The simulator traverses the linked list for the calculated set index to find a matching `tag`.
2.  **On Hit:** The line is unlinked and moved to the **Head** (MRU). If the access is a "store" and the policy is Write-Back, the line is marked `dirty`.
3.  **On Miss:**
    * If there is an empty slot, the data is loaded directly.
    * If the set is full, the **Tail** (LRU) line is evicted.
    * **Eviction Logic:** If the evicted line is `dirty`, a "copy back" to memory is triggered to preserve data integrity.
4.  **Fetch:** The new block is loaded, and the `demand_fetches` counter is incremented.

### 3. Consistency Maintenance (`flush`)
For Write-Back caches, the `flush()` function is called at the end of the simulation. It iterates through all sets and writes any remaining `dirty` blocks back to main memory to provide an accurate count of total memory traffic.

---

## Technical Implementation

### Data Structures
* `cache_line`: Stores the tag, dirty status, and pointers for the LRU list.
* `cache`: Contains the metadata for the cache (size, associativity, set counts) and an array of LRU lists.
* `cache_stat`: A structure dedicated to incrementing performance metrics.

### Build Requirements
The simulator requires the `math.h` library for logarithmic calculations.
```bash
gcc -o cachesim main.c cache.c -lm
```
## Usage Example
// Configure a 16KB 4-way Set-Associative Cache
set_cache_param(CACHE_PARAM_USIZE, 16384);
set_cache_param(CACHE_PARAM_ASSOC, 4);
set_cache_param(CACHE_PARAM_WRITEBACK, TRUE);

init_cache();
// ... run traces through perform_access() ...
flush();
print_stats();
