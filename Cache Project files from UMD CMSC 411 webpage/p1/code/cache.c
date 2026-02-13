/*
 * cache.c
 */


#include <stdlib.h>
#include <stdio.h>
#include <math.h>

#include "cache.h"
#include "main.h"

/* cache configuration parameters */
static int cache_split = 0;
static int cache_usize = DEFAULT_CACHE_SIZE;
static int cache_isize = DEFAULT_CACHE_SIZE; 
static int cache_dsize = DEFAULT_CACHE_SIZE;
static int cache_block_size = DEFAULT_CACHE_BLOCK_SIZE;
static int words_per_block = DEFAULT_CACHE_BLOCK_SIZE / WORD_SIZE;
static int cache_assoc = DEFAULT_CACHE_ASSOC;
static int cache_writeback = DEFAULT_CACHE_WRITEBACK;
static int cache_writealloc = DEFAULT_CACHE_WRITEALLOC;

/* cache model data structures */
static Pcache icache;
static Pcache dcache;
static cache c1;
static cache c2;
static cache_stat cache_stat_inst;
static cache_stat cache_stat_data;

/************************************************************/
void set_cache_param(param, value)
  int param;
  int value;
{

  switch (param) {
  case CACHE_PARAM_BLOCK_SIZE:
    cache_block_size = value;
    words_per_block = value / WORD_SIZE;
    break;
  case CACHE_PARAM_USIZE:
    cache_split = FALSE;
    cache_usize = value;
    break;
  case CACHE_PARAM_ISIZE:
    cache_split = TRUE;
    cache_isize = value;
    break;
  case CACHE_PARAM_DSIZE:
    cache_split = TRUE;
    cache_dsize = value;
    break;
  case CACHE_PARAM_ASSOC:
    cache_assoc = value;
    break;
  case CACHE_PARAM_WRITEBACK:
    cache_writeback = TRUE;
    break;
  case CACHE_PARAM_WRITETHROUGH:
    cache_writeback = FALSE;
    break;
  case CACHE_PARAM_WRITEALLOC:
    cache_writealloc = TRUE;
    break;
  case CACHE_PARAM_NOWRITEALLOC:
    cache_writealloc = FALSE;
    break;
  default:
    printf("error set_cache_param: bad parameter value\n");
    exit(-1);
  }

}
/************************************************************/

/************************************************************/
void init_cache()
{
    int i, j;
    Pcache cache_to_init;

    /* If unified, set I and D pointers to c1 and use usize. */
    if (cache_split == FALSE) {
        icache = &c1; 
        dcache = &c1;
        icache->size = cache_usize;
        dcache->size = cache_usize; // Redundant but safe
    } else {
        /* If split, set I to c1 and D to c2. Use isize and dsize. */
        icache = &c1;
        dcache = &c2;
        icache->size = cache_isize;
        dcache->size = cache_dsize;
    }

    icache->associativity = cache_assoc; 
    dcache->associativity = cache_assoc; 
    
    // Loop through the two potential caches (icache and dcache)
    for (int k = 0; k < (cache_split ? 2 : 1); k++) {
        
        cache_to_init = (k == 0) ? icache : dcache;
        
        // Skip initialization if size is 0 (optional feature)
        if (cache_to_init->size == 0) continue; 

        //Dynamic calculations depend on the current cache's size
        
        /* N_sets = Cache Size / (Block Size * Associativity) */
        cache_to_init->n_sets = cache_to_init->size / (cache_block_size * cache_to_init->associativity);

        /* Block Offset Bits = log2(Block Size) */
        cache_to_init->index_mask_offset = LOG2(cache_block_size); 

        /* Index Mask calculation remains the same */
        cache_to_init->index_mask = (cache_to_init->n_sets - 1) << cache_to_init->index_mask_offset;

        /* Allocate memory for LRU lists and set contents */
        cache_to_init->LRU_head = (Pcache_line *) malloc(sizeof(Pcache_line) * cache_to_init->n_sets);
        if (cache_to_init->LRU_head == NULL) {
            printf("Error: Failed to allocate LRU_head memory.\n");
            exit(-1);
        }
        cache_to_init->LRU_tail = (Pcache_line *) malloc(sizeof(Pcache_line) * cache_to_init->n_sets);
        if (cache_to_init->LRU_tail == NULL) {
            printf("Error: Failed to allocate LRU_tail memory.\n");
            exit(-1);
        }
        cache_to_init->set_contents = (int *) malloc(sizeof(int) * cache_to_init->n_sets);
        if (cache_to_init->set_contents == NULL) {
            printf("Error: Failed to allocate set_contents memory.\n");
            exit(-1);
        }
        /* Initialize all sets: allocate and link 'Associativity' number of lines per set */
        for (i = 0; i < cache_to_init->n_sets; i++) {
            
            cache_to_init->LRU_head[i] = (Pcache_line)NULL;
            cache_to_init->LRU_tail[i] = (Pcache_line)NULL;
            cache_to_init->set_contents[i] = 0; 
            
            for (j = 0; j < cache_to_init->associativity; j++) {
                Pcache_line new_line = (Pcache_line) malloc(sizeof(cache_line));
                if (new_line == NULL) {
                    printf("Error: Failed to allocate cache line memory.\n");
                    exit(-1);
                }
                new_line->tag = 0;
                new_line->dirty = FALSE;
                
                insert(&(cache_to_init->LRU_head[i]), &(cache_to_init->LRU_tail[i]), new_line);
            }
        }
        cache_to_init->contents = 0;
    }
    
    // Stats must be initialized separately for I and D
    cache_stat_inst.accesses = 0;
    cache_stat_inst.misses = 0;
    cache_stat_inst.replacements = 0;
    cache_stat_inst.demand_fetches = 0;
    cache_stat_inst.copies_back = 0;

    cache_stat_data.accesses = 0;
    cache_stat_data.misses = 0;
    cache_stat_data.replacements = 0;
    cache_stat_data.demand_fetches = 0;
    cache_stat_data.copies_back = 0;
}

/************************************************************/

/************************************************************/
void perform_access(addr, access_type)
    unsigned addr, access_type;
{
    unsigned block_addr, tag_addr, set_index;
    Pcache current_cache;
    Pcache_line line, victim_line; // victim_line is used for replacement
    Pcache_stat stats; 
    int is_hit = FALSE;
    current_cache = icache;

    if (access_type == TRACE_INST_LOAD) {
        current_cache = icache;
        stats = &cache_stat_inst;
    } else { /* TRACE_DATA_LOAD or TRACE_DATA_STORE */
        current_cache = dcache;
        stats = &cache_stat_data;
    }
    stats->accesses++;

    /* 2. Deconstruct the Address (using dynamic offsets) */
    block_addr = addr >> current_cache->index_mask_offset; 
    set_index = block_addr % current_cache->n_sets;
    tag_addr = block_addr / current_cache->n_sets;
    
    // Start at the head of the set's LRU list
    line = current_cache->LRU_head[set_index];


    /* 3. Check for Cache Hit (Iterate through all lines in the set) */
    while (line != (Pcache_line)NULL) {
        
        /* Check if the line is valid AND the tags match */
        if (line->tag == tag_addr && (line->tag != 0 || current_cache->set_contents[set_index] > 0)) {
            is_hit = TRUE;
            break;
        }

        // Check for an empty line (only happens when set_contents < Associativity)
        if (line->tag == 0 && current_cache->set_contents[set_index] < current_cache->associativity) {
            // This is an invalid/empty line, stop search, treat as a miss that will fill this slot
            break; 
        }

        line = line->LRU_next;
    }


    if (is_hit) {
        
        /* HIT: Move the line to the MRU position (head of LRU list) */
        
        delete(&(current_cache->LRU_head[set_index]), &(current_cache->LRU_tail[set_index]), line);
        insert(&(current_cache->LRU_head[set_index]), &(current_cache->LRU_tail[set_index]), line);
        
        if (access_type == TRACE_DATA_STORE) {
            
            if (cache_writeback == TRUE) {
                /* Write-Back Policy: Mark the line as dirty, no memory traffic */
                line->dirty = TRUE;
            } else {
                /* Write-Through Policy: Write immediately to memory */
                stats->copies_back += words_per_block; // Write to memory
                line->dirty = FALSE; // Never dirty in write-through
            }
        }
        
    } else {
        
        /* MISS */
        stats->misses++;
        if (access_type == TRACE_DATA_STORE && cache_writealloc == FALSE) {
            /* WRITE NO ALLOCATE: Write directly to memory and do not load into cache. */
            stats->copies_back += words_per_block;
            return; /* Exit the function after writing to memory */
        }
        /* 4. Determine Slot for Replacement/Insertion */
        
        // a) Check if there is an empty slot (Cold Miss)
        if (current_cache->set_contents[set_index] < current_cache->associativity) {
            // Found a line that was still at the end of the list and never used (tag=0)
            victim_line = current_cache->LRU_tail[set_index];
            current_cache->set_contents[set_index]++; // Increment valid entry count
            current_cache->contents++;
            
        } else {
            // b) No empty slot, MUST REPLACE the LRU line (Conflict or Capacity Miss)
            stats->replacements++;
            
            // The LRU line is always at the tail of the list
            victim_line = current_cache->LRU_tail[set_index];

            /* Check Write-Back Policy on Replacement */
            if (victim_line->dirty == TRUE) {
                stats->copies_back += words_per_block;
            }
        }
        
        // 5. Update the Victim Line with New Data (It becomes the MRU line)
        
        // Move the line to the MRU position (head of LRU list)
        delete(&(current_cache->LRU_head[set_index]), &(current_cache->LRU_tail[set_index]), victim_line);
        insert(&(current_cache->LRU_head[set_index]), &(current_cache->LRU_tail[set_index]), victim_line);
        
        // Fetch New Block
        stats->demand_fetches += words_per_block;

        // Update the line with the new tag
        victim_line->tag = tag_addr;

        if (access_type == TRACE_DATA_STORE) {
            
            if (cache_writealloc == TRUE) {
                if (cache_writeback == TRUE) {
                    /* Write Allocate, Write Back: New line is dirty */
                    victim_line->dirty = TRUE;
                } else {
                    /* Write Allocate, Write Through: New line is clean, and we write to memory */
                    stats->copies_back += words_per_block; // Write to memory
                    victim_line->dirty = FALSE;
                }
            }
            // else: Write No Allocate (implemented in the next step)
        } else {
            /* Read miss: The new line is clean */
            victim_line->dirty = FALSE;
        }
    }
}
/************************************************************/

/************************************************************/

void flush()
{
    int i;
    Pcache_line line;

    /* Only flush if the policy is Write-Back (cache_writeback == TRUE) */
    if (cache_writeback == FALSE) return;
    /* Iterate through all sets in the unified/split caches */
    // loop through both I and D caches if split is enabled
    for (int k = 0; k < (cache_split ? 2 : 1); k++) {
        Pcache current_cache = (k == 0) ? icache : dcache;
        Pcache_stat current_stats = (k == 0) ? &cache_stat_inst : &cache_stat_data;

        for (i = 0; i < current_cache->n_sets; i++) {
            
            // Iterate through all lines in the set's LRU list (since all are allocated)
            line = current_cache->LRU_head[i];
            
            for (int j = 0; j < current_cache->associativity; j++) {
                
                if (line == (Pcache_line)NULL) break; // Should not happen if init is correct

                if (line->dirty == TRUE) {
                    /* If dirty, it must be written back to memory */
                    current_stats->copies_back += words_per_block;
                    line->dirty = FALSE; /* Line is now clean */
                }
                line = line->LRU_next;
            }
        }
    }
}
/************************************************************/

/************************************************************/
void delete(head, tail, item)
  Pcache_line *head, *tail;
  Pcache_line item;
{
  if (item->LRU_prev) {
    item->LRU_prev->LRU_next = item->LRU_next;
  } else {
    /* item at head */
    *head = item->LRU_next;
  }

  if (item->LRU_next) {
    item->LRU_next->LRU_prev = item->LRU_prev;
  } else {
    /* item at tail */
    *tail = item->LRU_prev;
  }
}
/************************************************************/

/************************************************************/
/* inserts at the head of the list */
void insert(head, tail, item)
  Pcache_line *head, *tail;
  Pcache_line item;
{
  item->LRU_next = *head;
  item->LRU_prev = (Pcache_line)NULL;

  if (item->LRU_next)
    item->LRU_next->LRU_prev = item;
  else
    *tail = item;

  *head = item;
}
/************************************************************/

/************************************************************/
void dump_settings()
{
  printf("*** CACHE SETTINGS ***\n");
  if (cache_split) {
    printf("  Split I- D-cache\n");
    printf("  I-cache size: \t%d\n", cache_isize);
    printf("  D-cache size: \t%d\n", cache_dsize);
  } else {
    printf("  Unified I- D-cache\n");
    printf("  Size: \t%d\n", cache_usize);
  }
  printf("  Associativity: \t%d\n", cache_assoc);
  printf("  Block size: \t%d\n", cache_block_size);
  printf("  Write policy: \t%s\n", 
	 cache_writeback ? "WRITE BACK" : "WRITE THROUGH");
  printf("  Allocation policy: \t%s\n",
	 cache_writealloc ? "WRITE ALLOCATE" : "WRITE NO ALLOCATE");
}
/************************************************************/

/************************************************************/
void print_stats()
{
  printf("\n*** CACHE STATISTICS ***\n");

  printf(" INSTRUCTIONS\n");
  printf("  accesses:  %d\n", cache_stat_inst.accesses);
  printf("  misses:    %d\n", cache_stat_inst.misses);
  if (!cache_stat_inst.accesses)
    printf("  miss rate: 0 (0)\n"); 
  else
    printf("  miss rate: %2.4f (hit rate %2.4f)\n", 
	 (float)cache_stat_inst.misses / (float)cache_stat_inst.accesses,
	 1.0 - (float)cache_stat_inst.misses / (float)cache_stat_inst.accesses);
  printf("  replace:   %d\n", cache_stat_inst.replacements);

  printf(" DATA\n");
  printf("  accesses:  %d\n", cache_stat_data.accesses);
  printf("  misses:    %d\n", cache_stat_data.misses);
  if (!cache_stat_data.accesses)
    printf("  miss rate: 0 (0)\n"); 
  else
    printf("  miss rate: %2.4f (hit rate %2.4f)\n", 
	 (float)cache_stat_data.misses / (float)cache_stat_data.accesses,
	 1.0 - (float)cache_stat_data.misses / (float)cache_stat_data.accesses);
  printf("  replace:   %d\n", cache_stat_data.replacements);

  printf(" TRAFFIC (in words)\n");
  printf("  demand fetch:  %d\n", cache_stat_inst.demand_fetches + 
	 cache_stat_data.demand_fetches);
  printf("  copies back:   %d\n", cache_stat_inst.copies_back +
	 cache_stat_data.copies_back);
}
/************************************************************/




