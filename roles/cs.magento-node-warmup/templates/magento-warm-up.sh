#!/usr/bin/env bash

set -e

WARMUP_HOST_FAKE="{{ magento_node_warmup_host_fake }}"
WARMUP_BASE_URL="http://localhost:{{ magento_node_warmup_local_port }}"
WARMUP_URLS='{{ magento_node_warmup_url_paths | join(' ') }}'

for URL in $WARMUP_URLS ; do
    curl \
        -Lsk \
        -w "[$WARMUP_HOST_FAKE] (%{time_starttransfer}s) [%{http_code}<-] %{url_effective}\n" \
        -H "Host: $WARMUP_HOST_FAKE" \
        -o /dev/null \
            "$WARMUP_BASE_URL$URL"
done