mageops-info-configured() {
   find $MAGEOPS_ETC_INFOD_DIR -type f -name '*.sh' 2>/dev/null | grep sh &>/dev/null
}

mageops-info() {
  if mageops-info-configured ; then
    for FRAGMENT in $MAGEOPS_ETC_INFOD_DIR/* ; do
      source "$FRAGMENT"
    done
  else
    echo "Cannot show MageOps info - no info fragments found in directory /etc/mageops/info.d" >&2
    return 12
  fi
}