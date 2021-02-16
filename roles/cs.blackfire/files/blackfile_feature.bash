#!/usr/bin/env bash

feature__flag_name="blackfire_apm"

feature::apply() {
    local expected
    local current

    expected="$(feature::expected_value)"
    expected="$(feature::normalize_expected "$expected")"
    current="$(feature::current_value)"

    if [ "$expected" != "$current" ];then
        feature::update "$expected"
    fi
}

feature::normalize_expected() {
    local value=$1

    case $value in
    1) echo 1 ;;
    yes) echo 1 ;;
    true) echo 1 ;;
    enable) echo 1 ;;
    enabled) echo 1 ;;
    active) echo 1 ;;
    activated) echo 1 ;;
    *) echo 0 ;;
    esac
}

feature::expected_value() {
    features::read_feature_flag "$feature__flag_name" "0"
}

feature::current_value() {
    local current

    current="$(grep blackfire.apm_enabled /etc/php.d/zz-blackfire.ini | sed 's/.*=\s*\(.*\)\s*$/\1/')"

    if [ -z "$current" ];then
        current="0"
    fi

    echo "$current"
}

feature::update() {
    local value=$1
    local config

    echo "Setting blackfire apm to $value"

    config="$(grep -v blackfire.apm_enabled /etc/php.d/zz-blackfire.ini;echo "blackfire.apm_enabled = $value")"
    echo "$config" > /etc/php.d/zz-blackfire.ini

    echo "Restarting php-fpm and blackfire"
    systemctl restart php-fpm blackfire-agent
}
