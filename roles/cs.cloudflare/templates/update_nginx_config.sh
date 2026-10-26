#!/usr/bin/env bash
set -eou pipefail

IPLIST_URL=https://www.cloudflare.com/ips-v4
NGINX_CONFIG_LOCATION="{{ cloudflare_nginx_config }}"

generate_nginx_config() {
    local list=$1;
    local ip;
    for ip in $list;do
        echo "set_real_ip_from ${ip};"
    done
    # Match the socket peer, before real_ip rewrites the visitor address.
    echo 'geo $realip_remote_addr $cloudflare_peer {'
    echo '    default 0;'
    for ip in $list; do
        printf '    %s 1;\n' "$ip"
    done
    echo '}'
    echo 'map $cloudflare_peer $cloudflare_source_port {'
    echo '    default $realip_remote_port;'
    echo '    1 $http_{{ cloudflare_source_port_header | lower | replace("-", "_") }};'
    echo '}'
}

update_nginx_config() {
    local iplist;
    local config_content;

    iplist="$(curl -sfL "${IPLIST_URL}")"
    # Refuse empty responses rather than replacing a working trust list.
    test -n "$iplist"
    config_content="$(generate_nginx_config "${iplist}")"
    if [ ! -f "$NGINX_CONFIG_LOCATION" ] || [ "$(cat "$NGINX_CONFIG_LOCATION")" != "$config_content" ]; then
        echo "Updating cloudflare configuration"
        printf '%s\n' "$config_content" > "$NGINX_CONFIG_LOCATION"
        nginx -t
        echo "Reloading nginx"
        systemctl reload nginx
    else
        echo "Cloudflare configuration up to date"
    fi
}

update_nginx_config
