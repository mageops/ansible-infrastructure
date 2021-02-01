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

def pick_nonempty_keys(object={}):
    return { key: val for key, val in object.items() if bool(val) }

# Returns list of keys that differ between two dicts - that are present in
# either of them but not in both or have different value
def dict_diff_keys(a={}, b={}):
    return [ d[0] for d in set(a.items()).symmetric_difference(set(b.items())) ]

# Same as dict_diff but returns a dict with changed values - the value from
# first dict is used if key is present in both
def dict_diff(has={}, had={}):
    return { key: has[key] if key in has else had[key] for key, val in set(has.items()).symmetric_difference(set(had.items())) }

def normalize_number(val):
    try:
        return int(val)
    except ValueError:
        pass

    try:
        return float(val)
    except ValueError:
        pass

    return val

def dict_normalize_numbers(object={}):
    return { key: normalize_number(val) for key, val in object.items() }

class FilterModule(object):
    def filters(self):
        return {
            'remap_keys': remap_keys,
            'pick_keys': pick_keys,
            'reject_keys': reject_keys,
            'prefix_keys': prefix_keys,
            'pick_prefixed_keys': pick_prefixed_keys,
            'dict_to_tag_list': dict_to_tag_list,
            'pick_nonempty_keys': pick_nonempty_keys,
            'dict_diff_keys': dict_diff_keys,
            'dict_diff': dict_diff,
            'dict_normalize_numbers': dict_normalize_numbers
        }

