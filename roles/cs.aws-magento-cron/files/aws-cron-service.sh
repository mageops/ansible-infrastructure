#!/usr/bin/env bash
set -e

source "$(dirname "${BASH_SOURCE[0]}")/../lib/mageops/libaws.bash"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/mageops/libmageops.bash"

main::trigger_cron() {
    cd "$MAGENTO_ROOT_DIR"
    php "$MAGENTO_ROOT_DIR/bin/magento" cron:run
}

main::main() {
    if [ -z "$MAGENTO_ROOT_DIR" ];then
        echo "MAGENTO_ROOT_DIR env is not set!"
        exit 1
    fi
    while sleep 60;do
        if mageops::assert_tag_value "Cron" "yes";then
            main::trigger_cron &
        fi
    done
}

main::main "$@"
