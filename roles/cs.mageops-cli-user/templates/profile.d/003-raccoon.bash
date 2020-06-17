#!/usr/bin/env bash

mageops-raccoon-banner() {
cat <<ENDBANNER
      $(echo -e '\e[1;95m')____
     / __ \\____  ______________  ____  ____
    / /_/ / __ \`/ ___/ ___/ __ \\/ __ \\/ __ \\
   / _, _/ /_/ / /__/ /__/ /_/ / /_/ / / / /
  /_/ |_|\\__,_/\\___/\\___/\\____/\\____/_/ /_/

 $(echo -e '\e[90m')dev environment automation for MageSuite$(echo -e '\e[0m')
            powered by MageOps
ENDBANNER
}

cat <<ENDINFO
{% if raccoon_project_production_mode -%}
Warning! Magento is configured to run in PRODUCTION mode.
This environment is not suitable for development by default.
{% endif %}

{% if mageops_app_user | default(false, true) and mageops_cli_user_name == mageops_app_user and 'wheel' in mageops_cli_user_groups -%}
Passwordless sudo / su is enabled for this user.
{% endif %}

{% if magento_base_url | default(false, true) -%}
Magento base URL: {{ magento_base_url }}
{% endif -%}
{% if mageops_app_user | default(false, true) and mageops_cli_user_name != mageops_app_user -%}
App user: {{ mageops_app_user }}
{% endif -%}
Projects dir: {{ mageops_app_web_dir }}
Active project symlink: {{ magento_live_release_dir }}
Default project dir: {{ raccoon_project_dir }}
Uncached HTTP port: {{ nginx_app_port }}
Varnish port: {{ mageops_varnish_port }}
{% if mageops_https_termination_enable and https_termination_hosts | length > 0 -%}
HTTPS hosts: {{ https_termination_hosts | map(attribute='servername') | join(', ') }}.
{% endif -%}

mageops_public_ip_v4_api_ur

{{ raccoon_login_info_extra | default('') }}
ENDINFO

magento_release_dir