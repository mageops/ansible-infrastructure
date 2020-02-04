function ui::header() {
    echo -e "\n \033[0;36m--------  \033[0;35m$@  \033[0;36m-------- \033[0m\n"
}

function ui::spacer() {
    echo -e "\n\033[0;36m ----------------\033[0m\n"
}

function ui::prefix-lines() {
    local _PREFIX=${1:-}
    sed -e 's/^/'"$_PREFIX"'/g'
}

function ui::cmd-prefixed() {
    local _PREFIX=${1:- }
    shift
    $@ | ui::prefix-lines "$_PREFIX"
}

function ui::cmd-indented() {
    ui::cmd-prefixed ' ' $@
}