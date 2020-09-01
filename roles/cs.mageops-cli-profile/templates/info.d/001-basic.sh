export MAGEOPS_PROJECT="{{ mageops_project }}"
export MAGEOPS_ENVIRONMENT="{{ mageops_environment }}"

export MAGEOPS_APP_TYPE="{{ mageops_app_type }}"
export MAGEOPS_APP_NAME="{{ mageops_app_name }}"
export MAGEOPS_NODE_ROLE="{{ mageops_node_role }}"

{% if magento_live_release_dir is defined -%}
export MAGEOPS_MAGENTO_LIVE_RELEASE_DIR="{{ magento_live_release_dir }}"
{% endif %}

{% if magento_user is defined -%}
export MAGEOPS_MAGENTO_USER="{{ magento_user }}"
export MAGEOPS_MAGENTO_GROUP="{{ magento_group }}"
{% endif %}

{% if magento_version is defined %}
export MAGEOPS_MAGENTO_VERSION="{{ magento_version }}"
{% endif %}