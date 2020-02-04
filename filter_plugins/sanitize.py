from __future__ import (absolute_import, division, print_function)
__metaclass__ = type


from ansible.plugins.inventory import to_safe_group_name

class FilterModule(object):
    def filters(self):
        return {
            'to_safe_group_name': to_safe_group_name,
        }

