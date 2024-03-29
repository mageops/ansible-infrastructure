#!/usr/bin/env bash

feature__flag_name="newrelic_apm"
feature__license_key="newrelic_license_key"

feature::apply() {
    local expected
    local current

    expected="$(feature::expected_value)"
    expected="$(feature::normalize_expected "$expected")"
    current="$(feature::current_value)"
    current_license="$(feature::current_license_value)"
    expected_license="$(feature::expected_license_value)"

    if [ -z "$expected_license" ];then
        # We cannot enable the feature without a license key
        expected="false"
    fi
    if [ "$expected" != "$current" ] || [ "$expected_license" != "$current_license" ];then
        feature::update "$expected" "$expected_license"
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

feature::expected_license_value() {
    features::read_feature_flag "$feature__license_key" ""
}

feature::current_value() {
    local current

    current="$(grep '^newrelic.enabled' /etc/php.d/newrelic.ini | sed 's/.*=\s*\(.*\)\s*$/\1/')"

    if [ -z "$current" ];then
        current="true"
    fi

    echo "$current"
}

feature::current_license_value() {
    local current

    current="$(grep '^newrelic.license' /etc/php.d/newrelic.ini | sed 's/.*=\s*"\(.*\)"\s*$/\1/')"

    echo "$current"
}

feature::update() {
    local value=$1
    local license=$2

    echo "Setting newrelic apm to $value"
    sed -i -e "s/newrelic.enabled[[:space:]]=[[:space:]].*/newrelic.enabled = ${value}/" /etc/php.d/newrelic.ini
    sed -i -e "s/newrelic.license[[:space:]]=[[:space:]].*/newrelic.license = \"${license}\"/" /etc/php.d/newrelic.ini
    echo "Reloading php-fpm"
    systemctl reload php-fpm
}
