if [ ! -z "$MAGEOPS_ETC_INFOD_DIR" ] && mageops-info-configured ; then
  if [ -f "$HOME/.mageops/first-login.lock" ] ; then
    echo -e "Tip: Get information about this environment witu `mageops-info` command.\n"
  else
    mkdir -p "$HOME/.mageops"
    touch "$HOME/.mageops/first-login.lock"

    mageops-info

    echo -e "\nTip: This information is displayed only on first login, use `mageops-info` command to show it again.\n"
  fi
fi



