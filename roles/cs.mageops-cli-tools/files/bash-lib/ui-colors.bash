ui::c() {
  declare -A local _CODES=(
    [inf]="\033[0;34m"
    [wrn]="\033[0;33m"
    [scs]="\033[0;32m"
    [err]="\033[0;31m"
    [rst]="\033[0m"
  )
  
  local _RESET_CODE="${_CODES[rst]}"
  local _COLOR_CODE="${_CODES[$1]}"
  shift

  local _OUTER_STRING="$(echo -e "$@" | sed $'s,\x1b\\[0m,'"\\${_RESET_CODE}\\${_COLOR_CODE}"',g')"
  echo -e "${_COLOR_CODE}${_OUTER_STRING}${_RESET_CODE}"
}

ui::c_inf() { ui::c "inf" $@; }
ui::c_wrn() { ui::c "wrn" $@; }
ui::c_scs() { ui::c "scs" $@; }
ui::c_err() { ui::c "err" $@; }

ui::c_strip() { sed $'s,\x1b\\[[0-9;]*[a-zA-Z],,g'; }

ui::c_example() { echo "elo $(ui::c_inf "- co $(ui::c_scs "tam $(ui::c_wrn "głębiej") gdzieś") mój  -") ziomalu"; }
