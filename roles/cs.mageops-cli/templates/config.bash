#!/usr/bin/env bash

config__features_s3_bucket="{{ aws_s3_secret_bucket }}"
config__features_s3_config_path="s3://${config__features_s3_bucket}/features.json"
config__features_modules_path="{{ mageops_cli_features_dir }}"
config__opcache_file_paths=( "{% if php_opcache_web_file_cache_enable %}{{ php_opcache_user_home }}/{{ php_opcache_file_cache_user_dirname }}{% endif %}" "{% if php_cli_opcache_file_cache_enable %}/root/{{ php_opcache_file_cache_user_dirname }}{% endif %}" )
