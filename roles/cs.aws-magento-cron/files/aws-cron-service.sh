#!/usr/bin/env bash
set -e

get_current_instance_id() {
    curl -Lsf http://instance-data/latest/meta-data/instance-id
}

get_current_region() {
    curl -Lsf http://instance-data/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//'
}

get_ec2_tag_value() {
    local region=$1
    local instance_id=$2
    local tag_name=$3

    aws ec2 describe-tags --region "${region}" --filters "Name=resource-id,Values=${instance_id}" "Name=key,Values=${tag_name}" | jq -r '.Tags[].Value'
}

is_tag_exists() {
    local tag_name=$1
    local tag_value=$2

    local instance_id
    local found_value
    local region
    region="$(get_current_region)"
    instance_id="$(get_current_instance_id)"
    found_value="$(get_ec2_tag_value "$region" "$instance_id" "$tag_name")"

    if [ "$tag_value" = "$found_value" ];then
        return 0
    fi
    return 1
}

trigger_cron() {
    cd "$MAGENTO_ROOT_DIR"
    php "$MAGENTO_ROOT_DIR/bin/magento" cron:run
}

main() {
    if [ -z "$MAGENTO_ROOT_DIR" ];then
        echo "MAGENTO_ROOT_DIR env is not set!"
        exit 1
    fi
    while sleep 60;do
        if is_tag_exists "Cron" "yes";then
            trigger_cron &
        fi
    done
}

main "$@"
