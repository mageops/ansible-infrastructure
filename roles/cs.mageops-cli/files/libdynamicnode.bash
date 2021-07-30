#!/usr/bin/env bash
set -e

dynamicnode::register_node() {
    local node_name=$1
    curl -Lsf -H "secret: ${config__dynamicnode_secret}" -H "backend: ${node_name}" "${config__dynamicnode_endpoint_addr}/register"
}
