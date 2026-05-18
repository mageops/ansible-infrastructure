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
from jinja2 import Environment
from jinja2.nativetypes import NativeEnvironment
from ansible.errors import AnsibleParserError
from ansible.module_utils.common.text.converters import to_bytes, to_native, to_text
from ansible.plugins.filter.core import FilterModule as CoreFilterModule
from ansible.plugins.vars import BaseVarsPlugin
from ansible.inventory.host import Host
from ansible.inventory.group import Group
from ansible.plugins.test.core import TestModule as CoreTestModule
from ansible.utils.vars import combine_vars

CONFIG_GROUPS = ['all']
CONFIG_SUBDIR = 'vars'
GROUP_VARS_SUBDIR = 'group_vars'
CONFIG_TYPES = ['global', 'project']
CONFIG_TYPE_FILES_CACHE = {}
YAML_EXTENSIONS = ('.yml', '.yaml')
MAX_TEMPLATE_PASSES = 5
SIMPLE_VAR_PATTERN = re.compile(r'^\s*\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}\s*$')
FULL_TEMPLATE_PATTERN = re.compile(r'^\s*\{\{.*\}\}\s*$')

# ansible-core newer than the legacy behavior no longer expands these `vars/*`
# strings reliably during later variable access. We keep a dedicated Jinja
# environment here and register Ansible core filters/tests explicitly so values
# from vars/project and vars/global can still reference other vars the same way
# older Ansible setups allowed.
JINJA_ENV = Environment()
JINJA_ENV.filters.update(CoreFilterModule().filters())
JINJA_ENV.tests.update(CoreTestModule().tests())
NATIVE_JINJA_ENV = NativeEnvironment()
NATIVE_JINJA_ENV.filters.update(CoreFilterModule().filters())
NATIVE_JINJA_ENV.tests.update(CoreTestModule().tests())

def get_entity_name(entity):
    if isinstance(entity, Host):
        return "host: %s" % (entity.get_name())

    if isinstance(entity, Group):
        return "group: %s" % (entity.get_name())

    return "unknown: %s" % (str(entity))


def should_skip_path(path):
    return (
        re.search(r'/(tasks|certs|certificates|files|templates|resources|roles|playbooks)/', path)
        or re.search(r'/(?:\.[^/]+|[^/]+~)(?:/|$)', path)
    )


def list_config_type_files(config_dir_path, config_type):
    config_type_path = os.path.join(config_dir_path, config_type)

    if not os.path.exists(config_type_path) or should_skip_path(config_type_path):
        return []

    if os.path.isfile(config_type_path):
        return [config_type_path] if config_type_path.endswith(YAML_EXTENSIONS) else []

    found_files = []

    for root, dirnames, filenames in os.walk(config_type_path):
        dirnames[:] = [
            dirname for dirname in sorted(dirnames)
            if not should_skip_path(os.path.join(root, dirname))
        ]

        for filename in sorted(filenames):
            found = os.path.join(root, filename)

            if should_skip_path(found) or not found.endswith(YAML_EXTENSIONS):
                continue

            found_files.append(found)

    return found_files


def load_yaml_file(loader, path):
    if not os.path.exists(path) or should_skip_path(path) or not path.endswith(YAML_EXTENSIONS):
        return {}

    data = loader.load_from_file(path, cache=True, unsafe=False)

    return data if data else {}


def load_group_vars_context(loader, base_dir):
    group_vars_dir_path = os.path.join(base_dir, GROUP_VARS_SUBDIR)
    context = {}

    for filename in ('all.yml', 'all.yaml'):
        context = combine_vars(context, load_yaml_file(loader, os.path.join(group_vars_dir_path, filename)))

    return context


def resolve_templates_with_context(loader, base_variables, data):
    rendered = data

    for _ in range(MAX_TEMPLATE_PASSES):
        combined_variables = combine_vars(base_variables, rendered)
        next_rendered = render_value(combined_variables, rendered)

        if next_rendered == rendered:
            break

        rendered = next_rendered

    return rendered


def render_string(variables, value):
    try:
        if FULL_TEMPLATE_PATTERN.match(value):
            # Preserve native types for values that are entirely a Jinja
            # expression. Newer ansible-core stopped resolving these reliably
            # for vars loaded from vars/*, but conditionals still need actual
            # booleans instead of "True"/"False" strings.
            return NATIVE_JINJA_ENV.from_string(value).render(variables)

        return JINJA_ENV.from_string(value).render(variables)
    except Exception:
        return value


def render_value(variables, value):
    if isinstance(value, dict):
        rendered_dict = {}

        for key, item in value.items():
            rendered_key = render_value(variables, key)
            rendered_item = render_value(variables, item)
            rendered_dict[rendered_key] = rendered_item

        return rendered_dict

    if isinstance(value, list):
        rendered_list = []

        for item in value:
            rendered_list.append(render_value(variables, item))

        return rendered_list

    if isinstance(value, tuple):
        rendered_items = []

        for item in value:
            rendered_items.append(render_value(variables, item))

        return tuple(rendered_items)

    if isinstance(value, str):
        return render_string(variables, value)

    return value

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

        processable_entities = [
            entity for entity in entities
            if (
                isinstance(entity, Host)
                or (isinstance(entity, Group) and entity.get_name() in CONFIG_GROUPS)
            )
        ]

        # We want to load vars only for regular inventory entities.
        if len(processable_entities) == 0:
            return {}

        # Skipping tasks templates and vars
        config_dir_path = to_text(os.path.realpath(to_bytes(os.path.join(self._basedir, CONFIG_SUBDIR))))
        data = {}
        # Older Ansible behavior effectively let vars loaded from `vars/*`
        # reference values from `group_vars/all.yml`. Newer ansible-core leaves
        # many such strings unresolved, so we explicitly seed the render
        # context with group_vars/all before loading MageOps vars files.
        entity_vars = load_group_vars_context(loader, self._basedir)

        for entity in processable_entities:
            if hasattr(entity, 'get_vars'):
                entity_vars = combine_vars(entity_vars, entity.get_vars())

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
                        found_files = list_config_type_files(config_dir_path, config_type)
                        if cache:
                            CONFIG_TYPE_FILES_CACHE[config_type] = found_files

                    for found in found_files:
                        self._display.vv("Loading MageOps configuration file: %s" % (found))

                        new_data = load_yaml_file(loader, found)

                        if new_data:
                            data = combine_vars(data, new_data)
                data = resolve_templates_with_context(loader, entity_vars, data)
            else:
                self._display.v("Skipping non-existent MageOps configuration dir: %s" % (config_dir_path))

        except Exception as e:
            raise AnsibleParserError(to_native(e))

        return data
