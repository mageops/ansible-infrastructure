#!/usr/bin/env bash

config__features_s3_bucket="{{ aws_s3_secret_bucket }}"
config__features_s3_config_path="s3://${config__features_s3_bucket}/features.json"
config__features_modules_path="{{ mageops_cli_features_dir }}"
config__dynamicnode_endpoint_addr="http://{{ mageops_varnish_host }}:{{ mageops_coredns_dynamic_http_port }}/"
config__dynamicnode_secret="{{ mageops_coredns_dynamic_secret }}"
config__aws_enabled="{{ aws_use | ternary('yes', 'no') }}"
config__dynamicnode_enabled="{{ mageops_dynamic_node_enabled | ternary('yes', 'no') }}"
