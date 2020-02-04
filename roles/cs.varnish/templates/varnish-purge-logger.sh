#!/usr/bin/env bash

set -euo pipefail

trap "echo 'Caught signal, terminating background jobs and exiting gracefully...'; jobs -p | xargs kill 2>/dev/null || true; exit 0" EXIT INT HUP QUIT

varnishlog \
    -g request \
    -I 'ReqHeader:X-Magento-Tags-Pattern:' \
    -q 'ReqMethod eq "PURGE" and ReqHeader ~ "X-Magento-Tags-Pattern:"' \
        | grep --line-buffered -E 'X-Magento-Tags-Pattern' \
        | sed -u 's/^.*X-Magento-Tags-Pattern:\s*//g' \
        | awk '{ print "[" strftime() "]", $0; fflush() }' \
        >> "{{ varnish_purge_logfile }}"