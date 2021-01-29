#!/usr/bin/env bash

feature__flag_name="example"

feature::apply() {
    local expected
    local current

    expected="$(feature::expected_value)"
    current="$(feature::current_value)"

    if [ "$expected" != "$current" ];then
        feature::update "$expected"
    fi
}

feature::expected_value() {
    features::read_feature_flag "$feature__flag_name" ""
}

feature::current_value() {
    cat /tmp/example_feature.txt || true
}

feature::update() {
    local value=$1

    echo "$value" > /tmp/example_feature.txt
}
