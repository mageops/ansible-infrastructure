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
        echo "    ${ip} 1;"
    done
    echo '}'
    echo 'map $http_{{ cloudflare_source_port_header | lower | replace("-", "_") }} $cloudflare_header_source_port {'
    echo '    default $http_{{ cloudflare_source_port_header | lower | replace("-", "_") }};'
    echo '    "" $realip_remote_port;'
    echo '}'
    echo 'map $cloudflare_peer $cloudflare_source_port {'
    echo '    default $realip_remote_port;'
    echo '    1 $cloudflare_header_source_port;'
    echo '}'
}

update_nginx_config() {
    local iplist;
    local config_content;
    local current_config;

    iplist="$(curl -sfL "${IPLIST_URL}")"
    test -n "$iplist"
    config_content="$(generate_nginx_config "${iplist}")"
    if [ -f "$NGINX_CONFIG_LOCATION" ]; then
        current_config="$(cat "$NGINX_CONFIG_LOCATION")"
        if [ "$current_config" = "$config_content" ]; then
            echo "Cloudflare configuration up to date"
            return
        fi
    fi

    echo "Updating cloudflare configuration"
    echo "$config_content" > "$NGINX_CONFIG_LOCATION"
    echo "Reloading nginx"
    systemctl reload nginx
}

update_nginx_config
