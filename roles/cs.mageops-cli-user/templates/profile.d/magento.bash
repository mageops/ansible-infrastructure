function mageops-consumers() {
    pgrep -f '[c]onsumers:start' | sort | xargs --no-run-if-empty ps ufp
}

function magcd() {
    cd "{{ magento_live_release_dir }}"
}

function magetocd() {
    magcd
}

alias mag="magcd && php bin/magento"
alias magcf="mag cache:flush"