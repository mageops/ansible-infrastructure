#!/usr/bin/env bash

features__config=""

features::load_config() {
    if [ -z "$features__config" ];then
        features__config="$(mageops::read_s3_file "$config__features_s3_config_path" || echo "{}")"
    fi
}

features::update_config() {
    if [ -n "$features__config" ];then
        mageops::update_s3_file "$config__features_s3_config_path" "$features__config"
    fi
}

features::read_feature_flag() {
    local name=$1
    local default_value=$2

    local value

    features::load_config
    value="$(echo "${features__config}" | jq -r ".${name}")"

    if [ "$value" = "null" ];then
        $value="$default_value"
    fi

    echo "${value}"
}


features::update_feature_flag() {
    local name=$1
    local value=$2

    features::load_config

    features__config="$(echo "$features__config" | jq ".${name}=\"${value}\"")"
    features::update_config
}


features::update_host_state() {
    features::load_config

    for module in "${config__features_modules_path}"/*.bash;do
        (
            source "$module"
            feature::apply
        )
    done
}
