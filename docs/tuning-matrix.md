# Tuning Matrix (RAM Tier)

默认按主机 RAM 自动分档；`bootstrap.env` 显式配置优先级更高。

| Tier | RAM | SWAP_GB | PG_MEM_LIMIT | PG_SHM | VALKEY_MEM_LIMIT | VALKEY_MAXMEM | shared_buffers | effective_cache_size | work_mem | maintenance_work_mem | max_connections |
|---|---|---:|---|---|---|---|---|---|---|---|---:|
| S | 4-<8 GiB | 2 | 1100m | 256mb | 256m | 192mb | 256MB | 768MB | 16MB | 128MB | 80 |
| M | 8-<16 GiB | 4 | 2200m | 512mb | 512m | 384mb | 512MB | 2048MB | 16MB | 256MB | 120 |
| L | 16-<32 GiB | 8 | 5000m | 1gb | 1024m | 768mb | 1536MB | 6144MB | 32MB | 512MB | 200 |
| XL | >=32 GiB | 8 | 9000m | 2gb | 2048m | 1536mb | 3072MB | 12288MB | 32MB | 1024MB | 300 |

`FORCE_RAM_TIER=S|M|L|XL` 可强制指定档位。
