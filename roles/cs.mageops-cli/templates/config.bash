#!/usr/bin/env bash

config__features_s3_bucket="{{ aws_s3_secret_bucket }}"
config__features_s3_config_path="s3://${config__features_s3_bucket}/features.json"
config__features_modules_path="/usr/local/lib/mageops/features"
