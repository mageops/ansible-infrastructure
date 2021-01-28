## Varnish parameters calculation algorithm

Read this if you want to know how and when to set:
- `varnish_memory`
- `varnish_sys_mem_rel`
- `varnish_storage_mem_rel`
- `varnish_sys_mem_reserved`
- `varnish_thread_pool_max`
- `varnish_thread_pool_min`

And how their values are calculated.

1) **Calculate base memory pool assigned to be used by varnishd:**

   ```js
   varnish_base_mem_ceil = varnish_sys_mem_rel * ansible_memtotal_mb
   ```

   _...or if less than `varnish_sys_mem_reserved` is left for rest of the system from relative calculation then:_

   ```js
   varnish_base_mem_ceil = ansible_memtotal_mb - varnish_sys_mem_reserved
   ```

2) **Calculate memory left for threads and malloc storage out of the pool computed previously:**

   ```js
   varnish_dyn_mem_ceil = varnish_base_mem_ceil - varnish_vsl_space - varnish_vsm_space
   ```

3) **Calculate memory allocated for cached object malloc storage relative to memory left in pool:**

   _If `varnish_memory` var is empty then calculate_

   ```js
   varnish_storage_mem = varnish_storage_mem_rel * varnish_dyn_mem_ceil
   ```
   _...or if it's set to a fixed value:_

   ```js
   varnish_storage_mem = varnish_memory
   ```

4) **Calculate memory allocated for threads - everything left in the pool:**

    ```js
    varnish_thread_mem_ceil = varnish_dyn_mem_ceil - varnish_storage_mem
    ```

5) **Calculate the max number of threads per pool by dividing `varnish_thread_mem_ceil`
   by _estimated peak memory usage per-thread_ and the number of pools:**

   ```js
   varnish_thread_pool_max = varnish_thread_mem_ceil / varnish_thread_mem_est / varnish_thread_pools
   ```

6) **Calculate the min number of threads as _20%_ of `varnish_thread_pool_max` (but not less
   than _50_):**

   ```js
   varnish_thread_pool_min = varnish_thread_pool_max / 5
   ```




