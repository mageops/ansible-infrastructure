#!/usr/bin/env bash

set -e

WARMUP_HOST_FAKE="{{ magento_node_warmup_host_fake }}"
WARMUP_BASE_URL="http://localhost:{{ magento_node_warmup_local_port }}"
WARMUP_URLS='{{ magento_node_warmup_url_paths | join(' ') }}'

echo -e '[INFO] Started System Boot Magento Full Page Cache Warmup!\n' | wall -n

echo "[$(date -Iseconds)] [WARMUP] Started" > /tmp/magento-warm-up.log

for URL in $WARMUP_URLS ; do
    # Never fail, we don't want unhealthy degraded system state if this fails
    curl \
        -Lsk \
           -w "[$(date -Iseconds)] [%{http_code}] (%{time_starttransfer}s) GET %{url_effective}\n" \
        -H "Host: $WARMUP_HOST_FAKE" \
        -o /dev/null \
            "$WARMUP_BASE_URL$URL" \
        2>&1 \
	| tee -a /tmp/magento-warm-up.log \
        || true
done

echo "[$(date -Iseconds)] [WARMUP] Finished" >> /tmp/magento-warm-up.log

echo -e "[INFO] System Boot Magento Full Page Cache Warmup has been completed\n\n$(cat /tmp/magento-warm-up.log)\n" | wall -n

