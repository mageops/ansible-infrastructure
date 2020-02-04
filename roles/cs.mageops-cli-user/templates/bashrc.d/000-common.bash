function __mageops__echo-header() {
    echo -e "\n \033[0;36m--------  \033[0;35m$@  \033[0;36m-------- \033[0m\n"
}

function __mageops__echo-spacer() {
    echo -e "\n\033[0;36m ----------------\033[0m\n"
}

function __mageops__prefix-lines() {
    local _PREFIX=${1:- }
    sed -e 's/^/'"$_PREFIX"'/g'
}

function mageops-sys-status() {
    __mageops__echo-header "Host $(hostname)"

    uptime | __mageops__prefix-lines

    __mageops__echo-header "Disk IO"

    df -h | __mageops__prefix-lines

    __mageops__echo-spacer

    iostat -dmxht | __mageops__prefix-lines

    __mageops__echo-header "Memory"

    free -m | __mageops__prefix-lines

    __mageops__echo-spacer

    vmstat --stats | __mageops__prefix-lines

    __mageops__echo-header "Memory Top"

    mageops__top-mem | __mageops__prefix-lines

    __mageops__echo-header "CPU"

    mpstat | __mageops__prefix-lines

    __mageops__echo-spacer

    mpstat -P ALL | __mageops__prefix-lines

    __mageops__echo-header "CPU Top"

    mageops__top-cpu | __mageops__prefix-lines
}

function mageops-top-cpu() {
    ps -Ao user,pid,pcpu,pmem,args --sort=-pcpu | head -n 5
}

function mageops-top-mem() {
    ps -Ao user,pid,pcpu,pmem,args --sort=-pmem | head -n 5
}

