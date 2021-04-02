from __future__ import (absolute_import, division, print_function)

__metaclass__ = type


from ansible.errors import AnsibleError, AnsibleFilterError

import re

''' Strip leading and trailing whitespace from each line
    while keeping newlines intact '''
def strip_lines(text, collapse=True):
    text = re.sub('^[ \t]+|[ \t]+$', '', text, flags=re.MULTILINE)
    if not collapse:
        return text
    return re.sub('[\r\n]{2,}', '\n\n', text, flags=re.DOTALL)


class FilterModule(object):
    def filters(self):
        return {
            'strip_lines': strip_lines,
        }

