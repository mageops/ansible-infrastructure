export MAGEOPS_BASH_TOOLS_DIR="{{ mageops_cli_bash_tools_dir }}"
export MAGEOPS_BASH_LIB="{{ mageops_cli_bash_lib_entrypoint }}"
export MAGEOPS_BASH_LIB_DIR="{{ mageops_cli_bash_lib_entrypoint | dirname }}"

mageops::lib::load() {
  if [ ! -f "${MAGEOPS_BASH_LIB}" ] ; then
    echo "Cannot load MageOps Bash Tools Library: entrypoint does not exist at $MAGEOPS_BASH_LIB" >&2
    return 9
  fi
  
  source "${MAGEOPS_BASH_LIB}"
}