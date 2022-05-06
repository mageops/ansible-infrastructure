#!/usr/bin/env bash

feature__flag_name="newrelic_apm"

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
    1) echo true ;;
    yes) echo true ;;
    true) echo true ;;
    enable) echo true ;;
    enabled) echo true ;;
    active) echo true ;;
    activated) echo true ;;
    *) echo false ;;
    esac
}

feature::expected_value() {
    features::read_feature_flag "$feature__flag_name" "false"
}

feature::current_value() {
    local current

    current="$(grep '^newrelic.enabled' /etc/php.d/newrelic.ini | sed 's/.*=\s*\(.*\)\s*$/\1/')"

    if [ -z "$current" ];then
        current="true"
    fi

    echo "$current"
}

feature::update() {
    local value=$1
    local config

    echo "Setting newrelic apm to $value"
    sed -i -e "s/newrelic.enabled[[:space:]]=[[:space:]].*/newrelic.enabled = ${value}" /etc/php.d/newrelic.ini
    echo "Reloading php-fpm"
    systemctl reload php-fpm
}
