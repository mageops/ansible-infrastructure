#!/usr/bin/env bash

aws__token=""
aws__token_expire=0
aws__session_time=60

aws::_refresh_token() {
    local now

    now="$(date '+%s')"
    if [ "$now" -ge "$aws__token_expire" ];then
        aws__token="$(curl -sf -X PUT  -H "X-aws-ec2-metadata-token-ttl-seconds: $aws__session_time" "http://169.254.169.254/latest/api/token")"
        aws__token_expire="$(( now + aws__session_time))"
    fi
}

aws::_curl() {
    aws::_refresh_token
    curl -Lsf -H "X-aws-ec2-metadata-token: $aws__token" "$@"
}

aws::get_current_instance_id() {
    aws::_curl http://instance-data/latest/meta-data/instance-id || return 1
}

aws::get_current_instance_public_ip() {
    aws::_curl http://instance-data/latest/meta-data/public-ipv4 || return 1
}

aws::get_current_region() {
    aws::_curl http://instance-data/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//' || return 1
}
