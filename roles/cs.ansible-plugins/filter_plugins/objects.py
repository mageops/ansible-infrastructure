from __future__ import (absolute_import, division, print_function)

__metaclass__ = type


from ansible.errors import AnsibleError, AnsibleFilterError


def remap_keys(object={}, keymap={}):
  return { (keymap[key] if key in keymap else key): object[key] for key in object }


def pick_keys(object={}, keys=[]):
    return { key: object[key] for key in keys if key in object }


def reject_keys(object={}, keys=[]):
    return { key: object[key] for key in object if key not in keys }


def prefix_keys(object={}, prefix=''):
    return { prefix + key: object[key] for key in object }


def pick_prefixed_keys(object={}, prefix=''):
    return dict([(key, object[key]) for key in object if key.startswith(prefix)])


def dict_to_tag_list(object={}):
    return [ {k: v} for k, v in object.items() ]


class FilterModule(object):
    def filters(self):
        return {
            'remap_keys': remap_keys,
            'pick_keys': pick_keys,
            'reject_keys': reject_keys,
            'prefix_keys': prefix_keys,
            'pick_prefixed_keys': pick_prefixed_keys,
            'dict_to_tag_list': dict_to_tag_list
        }

