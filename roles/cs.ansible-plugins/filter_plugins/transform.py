from __future__ import (absolute_import, division, print_function)

__metaclass__ = type

from ansible.errors import AnsibleError, AnsibleFilterError
from ansible.module_utils._text import to_native

import json

try:
    from jq import jq
except ImportError:
    jq = None

def jq_transform(data, script):
    if not jq:
        raise AnsibleError('Please install "jq" python library on your controller in order to use this filter')

    try:
        program = jq(script)
    except ValueError as exc:
        raise AnsibleFilterError('Could not compile the jq script: %s' % to_native(exc))
    
    try:
        return program.transform(data)
    except ValueError as exc:
        raise AnsibleFilterError('The jq script has failed: %s' % to_native(exc))

class FilterModule(object):
    def filters(self):
        return {
            'jq': jq_transform,
        }
