#!/usr/bin/env bash
set -e

mageops::get_ec2_tag_value() {
    local region=$1
    local instance_id=$2
    local tag_name=$3

    aws ec2 describe-tags --region "${region}" \
        --filters "Name=resource-id,Values=${instance_id}" \
        "Name=key,Values=${tag_name}" | jq -r '.Tags[].Value' || return 1
}

mageops::get_tag_value() {
    local tag_name=$1

    local instance_id
    local found_value
    local region
    region="$(aws::get_current_region)"
    instance_id="$(aws::get_current_instance_id)"
    found_value="$(mageops::get_ec2_tag_value "$region" \
        "$instance_id" "$tag_name")"

    echo "$found_value"
}

mageops::is_tag_exists() {
    local tag_name=$1

    local instance_id
    local found_value
    local region
    region="$(aws::get_current_region)"
    instance_id="$(aws::get_current_instance_id)"
    found_value="$(mageops::get_ec2_tag_value "$region" \
        "$instance_id" "$tag_name")"

    if [ -n "$found_value" ];then
        return 0
    fi
    return 1
}

mageops::assert_tag_value() {
    local tag_name=$1
    local tag_value=$2

    local instance_id
    local found_value
    local region
    region="$(aws::get_current_region)"
    instance_id="$(aws::get_current_instance_id)"
    found_value="$(mageops::get_ec2_tag_value "$region" \
        "$instance_id" "$tag_name")"

    if [ "$tag_value" = "$found_value" ];then
        return 0
    fi
    return 1
}

mageops::read_s3_file() {
    local url=$1

    aws s3 cp "$url" -
}

mageops::update_s3_file() {
    local url=$1
    local content=$2

    echo "$content" | aws s3 cp - "$url"
}
