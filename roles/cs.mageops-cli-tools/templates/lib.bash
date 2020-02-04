#!/usr/bin/env bash

export MAGEOPS_BASH_LIB_DIR="{{ mageops_cli_bash_lib_dir }}"
export MAGEOPS_BASH_UPSTREAM_LIB_DIR="{{ mageops_cli_bash_lib_upstream_dir }}"

source "${MAGEOPS_BASH_LIB_DIR}"

import::add_path "${MAGEOPS_BASH_UPSTREAM_LIB_DI}"

