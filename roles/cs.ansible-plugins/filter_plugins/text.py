from __future__ import (absolute_import, division, print_function)

__metaclass__ = type

from ansible.errors import AnsibleError, AnsibleFilterError
import re
import textwrap

try:
    import sass
except ImportError:
    sass = None

''' Strip leading and trailing whitespace from each line
    while keeping newlines intact '''
def strip_lines(text, collapse=True):
    text = re.sub('^[ \t]+|[ \t]+$', '', text, flags=re.MULTILINE)
    if not collapse:
        return text
    return re.sub('[\r\n]{2,}', '\n\n', text, flags=re.DOTALL)

def sass_compile(**kwargs):
    if not sass:
        raise AnsibleError('Please install "libsass" python library on your controller in order to use this filter')

    try:
        return sass.compile(**kwargs)
    except sass.CompileError as exc:
        if 'filename' in kwargs:
            raise AnsibleFilterError('Could not compile the scss file "%s":' % (filename, to_native(exc)))
        # elif 'string' in kwargs:
            # raise AnsibleFilterError('Could not compile the scss "%s":' % (textwrap.shorten(kwargs['string'], width=64, placeholder='[...]'), to_native(exc)))
        else:
            raise AnsibleFilterError('The scss compilation failed:' % to_native(exc))

def scss_compile(string, output_style='nested'):
    return sass_compile(string=string, output_style=output_style)

def scss_compile_file(filename, output_style='nested'):
    return sass.compile(filename=filename, output_style=output_style)

class FilterModule(object):
    def filters(self):
        return {
            'strip_lines': strip_lines,
            'scss_compile': scss_compile,
        }

