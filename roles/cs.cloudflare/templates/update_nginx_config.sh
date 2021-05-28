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
}

update_nginx_config() {
    local iplist;
    local config_content;
    local current_config;

    iplist="$(curl -sfL "${IPLIST_URL}")"
    config_content="$(generate_nginx_config "${iplist}")"
    if [ -f "$NGINX_CONFIG_LOCATION" ];then
        current_config="$(cat ${NGINX_CONFIG_LOCATION})"
        if [ "${current_config}" = "${config_content}" ];then
            echo "Cloudflare configuration up to date"
            return
        fi
    fi

    echo "Updating cloudflare configuration"
    echo "${config_content}" > "$NGINX_CONFIG_LOCATION"
    echo "Reloading nginx"
    systemctl reload nginx
}

update_nginx_config
