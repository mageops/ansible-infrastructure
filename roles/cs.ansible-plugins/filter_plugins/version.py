from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible import errors

'''
- hosts: localhost
  connection: local
  gather_facts: yes
  vars:
  roles:
    - role: cs.ansible-plugins
  tasks:
    - debug:
        msg: |
          Normalized: {{ item[0] | version_normalize }} - {{ item[0] | version_normalize(upper_bound=true) }} {{ item[1] }} {{ item[2] | version_normalize }} - {{ item[2] | version_normalize(upper_bound=true) }}
          Result of {{ item | join(' ') }} is {{ result | to_json }}
      vars:
        result: "{{ item[0] | version_minor(item[3] | default(2)) is version(item[2], item[1]) }}"
      loop:
        - ['7.2.146.3-dev', '==' , '7.2']
        - ['7.2.146.3-dev', '==' , '7.2.1']
        - ['7.2.146.3-dev', '<' , '7.2.22222', 3]
        - ['7.2.146.3-dev', '>=' , '7.2']
        - [7.2, '<' , '7.3']
        - [7.99, '<' , '7.99.1']
        - [7.99, '<' , '7.999']
        - [9, '>' , '8.9.9']
      loop_control:
        label: "{{ item | join(' ') }}"
'''


def version_value(value):
  if value is None:
    return '0'

  try:
    return str(value)
  except ValueError:
    raise errors.AnsibleFilterError('Invalid version: %s not castable to str' % type(value).__name__)

def level_value(value):
  try:
    value = int(value)
  except ValueError:
    raise errors.AnsibleFilterError('Invalid version level: %s not castable to int' % type(value).__name__)

  if value < 0:
    raise errors.AnsibleFilterError('Version level must be >= 0')

  return value

def version_minor(version, level=2):
  version = version_value(version)
  level = level_value(level)

  return '.'.join(version.split('.')[:level])

def version_normalize(version, min_level=4, upper_bound=False):
  version = version_value(version)
  min_level = level_value(min_level)

  bound = '9999' if upper_bound else '0'

  els = version.split('.')
  els.extend([bound] * (min_level - len(els)))

  return '.'.join(els)

class FilterModule(object):
    def filters(self):
        return {
            'version_minor': version_minor,
            'version_normalize': version_normalize,
        }



