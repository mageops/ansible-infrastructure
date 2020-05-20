{% if php_fpm_debug_pool_xdebug_remote_port | default(false, true) and mageops_debug_token | default(false, true) %}
cat<<ENDMSG

  ------------------  $(echo -en "\033[1;36mXDebug Remote Host\033[0m")  ------------------

  $(echo -en "\033[1;36mDebugging token:\033[0m") $(echo -en "\033[0;35m{{ mageops_debug_token }}\033[0m")
  $(echo -en "\033[1;36mXDebug port:\033[0m") $(echo -en "\033[0;35m{{ php_fpm_debug_pool_xdebug_remote_port }}\033[0m")

  ---------------------------------------------------------

  1. Set up a tunnel from your $(echo -en "\033[1mlocal computer\033[0m"):

  $(echo -en "\033[0;35m")ssh -N \\
    -o ExitOnForwardFailure=yes \\
    -o GatewayPorts=yes \\
    -R {{ php_fpm_debug_pool_xdebug_remote_port }}:localhost:{{ php_fpm_debug_pool_xdebug_remote_port }} \\
      $(whoami)@$(curl -sL https://api.ipify.org)$(echo -en "\033[0m")

  2. Start debugging by adding query parameter to the URL:

  $(echo -en "\033[0;35m")?{{mageops_debug_token_query_param }}={{ mageops_debug_token }}$(echo -en "\033[0m")

  ----------------------------------------------------------

ENDMSG
{% endif %}
