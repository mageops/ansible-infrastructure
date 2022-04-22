from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

DOCUMENTATION = '''
    vars: mageops_vars
    short_description: Loads global infrastructure and project configuration from `vars/` subdirectory
    description:
      - Loads vars from yaml files in `vars/global` and `vars/project`
      - Hidden (starting with '.') and backup (ending with '~') files and directories are ignored.
    options:
      inventory_groups:
        description: Which inventory groups the vars shall be imported for
        default: ['all']
        type: list
        ini:
          - key: vars_inventory_groups
            section: mageops
        env:
          - name: ANSIBLE_MAGEOPS_VARS_INVENTORY_GROUPS
      config_types:
        description: Which config types (subdirs/files) to load from the configuration dir
        default: ['global', 'project']
        type: list
        ini:
          - key: vars_config_types
            section: mageops
        env:
          - name: ANSIBLE_MAGEOPS_VARS_CONFIG_TYPES
      config_dir:
        description: Relative (to playbook dir) path to the config directory
        default: vars
        type: string
        ini:
          - key: vars_config_dir
            section: mageops
        env:
          - name: ANSIBLE_MAGEOPS_VARS_CONFIG_DIR
    extends_documentation_fragment:
      - vars_plugin_staging
'''

import os
import re
from ansible import constants as C
from ansible.errors import AnsibleParserError
from ansible.module_utils._text import to_bytes, to_native, to_text
from ansible.plugins.vars import BaseVarsPlugin
from ansible.inventory.host import Host
from ansible.inventory.group import Group
from ansible.utils.vars import combine_vars

CONFIG_GROUPS = ['all']
CONFIG_SUBDIR = 'vars'
CONFIG_TYPES = ['global', 'project']
CONFIG_TYPE_FILES_CACHE = {}

def get_entity_name(entity):
    if isinstance(entity, Host):
        return "host: %s" % (entity.get_name())

    if isinstance(entity, Group):
        return "group: %s" % (entity.get_name())

    return "unknown: %s" % (str(entity))

class VarsModule(BaseVarsPlugin):
    REQUIRES_WHITELIST = False


    def get_vars(self, loader, path, entities, cache=True):
        if not isinstance(entities, list):
            entities = [entities]

        super(VarsModule, self).get_vars(loader, path, entities)

        # How to get options in vars plugin? There no `self.get_option()` :(

        # Skip global ansible configuration dirs, we want only play-local ones
        if self._basedir is None or self._basedir == 'None':
            return {}

        processable_entities = [entity for entity in entities if isinstance(entity, Group) and entity.get_name() in CONFIG_GROUPS]

        # We want to load vars only for the 'all' group
        if len(processable_entities) == 0:
            return {}

        # Skipping tasks templates and vars
        config_dir_path = to_text(os.path.realpath(to_bytes(os.path.join(self._basedir, CONFIG_SUBDIR))))
        data = {}

        try:
            if os.path.isdir(config_dir_path):
                self._display.v("Loading MageOps configuration directory: %s" % config_dir_path)

                for entity in entities:
                    self._display.vv("Loading MageOps configuration for %s" % (get_entity_name(entity)))

                for config_type in CONFIG_TYPES:
                    self._display.vv("Loading MageOps configuration type: %s" % config_type)

                    if cache and config_type in CONFIG_TYPE_FILES_CACHE:
                        found_files = CONFIG_TYPE_FILES_CACHE[config_type]
                    else:
                        found_files = loader.find_vars_files(config_dir_path, config_type, allow_dir=True)

                    for found in found_files:
                        if re.search(r'/(tasks|certs|certificates|files|templates|resources|roles|playbooks)/', found):
                            continue

                        self._display.vv("Loading MageOps configuration file: %s" % (found))

                        new_data = loader.load_from_file(found, cache=True, unsafe=True)

                        if new_data:
                            data = combine_vars(data, new_data)
            else:
                self._display.v("Skipping non-existent MageOps configuration dir: %s" % (config_dir_path))

        except Exception as e:
            raise AnsibleParserError(to_native(e))

        return data
