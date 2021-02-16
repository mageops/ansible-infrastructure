## Varnish parameters calculation algorithm

Read this if you want to know how and when to set:
- `varnish_memory`
- `varnish_sys_mem_rel`
- `varnish_storage_mem_rel`
- `varnish_sys_mem_reserved`
- `varnish_thread_pool_max`
- `varnish_thread_pool_min`

And how their values are calculated.

### Calculation steps

1) **Calculate base memory pool assigned to be used by varnishd:**

   ```js
   varnish_base_mem_quota = varnish_sys_mem_rel * ansible_memtotal_mb
   ```

   _...or if less than `varnish_sys_mem_reserved` is left for rest of the system from relative calculation then:_

   ```js
   varnish_base_mem_quota = ansible_memtotal_mb - varnish_sys_mem_reserved
   ```

2) **Calculate memory left for threads and malloc storage out of the pool computed previously:**

   ```js
   varnish_dyn_mem_quota = varnish_base_mem_quota - varnish_vsl_space - varnish_vsm_space
   ```

3) **Calculate memory allocated for cached object malloc storage relative to memory left in pool:**

   _If `varnish_memory` var is empty then calculate_

   ```js
   varnish_storage_mem = varnish_storage_mem_rel * varnish_dyn_mem_quota
   ```
   _...or if it's set to a fixed value:_

   ```js
   varnish_storage_mem = varnish_memory
   ```

4) **Calculate memory allocated for threads - everything left in the pool:**

    ```js
    varnish_thread_mem_quota = varnish_dyn_mem_quota - varnish_storage_mem
    ```

5) **Calculate the max number of threads per pool by dividing `varnish_thread_mem_quota`
   by _estimated peak memory usage per-thread_ and the number of pools (but not less than 20):**

   ```js
   varnish_thread_pool_max = varnish_thread_mem_quota / varnish_thread_mem_est / varnish_thread_pools
   ```

6) **Calculate the min number of threads as _20%_ of `varnish_thread_pool_max` (but not less
   than _50_):**

   ```js
   varnish_thread_pool_min = varnish_thread_pool_max / 5
   ```

### Calculation examples

#### A server with 4GB of RAM and 2vCPUs

Assuming role configuration:

```
varnish_memory: ~
varnish_sys_mem_rel: 0.9
varnish_storage_mem_rel: 0.8
```

We get as follows (final values rounded slightly for clarity):

```py
   3.60G == varnish_base_mem_quota   = 90% * 4G
   3.56G == varnish_dyn_mem_quota    = 3.60G - 31M - 1M
   2.85G == varnish_storage_mem      = 80% * 0.80G
   0.71G == varnish_thread_mem_quota = 3.56G - 2.85G
     910 == varnish_thread_pool_max  = 0.71G / 390k / 2
     182 == varnish_thread_pool_min  = 910 / 5
```


