# -*- coding: utf-8 -*-

import os
import re
from completor import Completor, vim
from completor.compat import to_unicode

WRAPPER = os.path.join(os.path.dirname(__file__), 'elixir_sense_wrapper.py')
RE_SUGGESTIONS = re.compile(r'kind:(?P<kind>[^,]*), word:(?P<word>[^,]*), abbr:(?P<abbr>[\w\W]*), menu:(?P<menu>[\w\W]*), info:(?P<info>[\w\W]*)$')


class Alchemist(Completor):
    filetype = 'elixir'
    trigger = r'(\w{2}|\.\w?)$'

    def format_cmd(self):
        binary = self.get_option('python_binary') or 'python'
        lnum, cnum = vim.current.window.cursor
        lines = "\n".join(vim.current.buffer[:])
        return [binary, WRAPPER, '--lnum', lnum, '--cnum', cnum, '--lines', lines]

    def on_complete(self, results):
        suggestions = []
        extended_autocomplete = bool(vim.vars.get('alchemist#extended_autocomplete'))

        for result in results:
            matches = RE_SUGGESTIONS.match(to_unicode(result, 'utf-8'))
            kind = matches.group('kind')
            word = matches.group('word')
            if kind == 'f':
                word = word.split('.')[-1]

            sugg = {
                'kind': kind,
                'word': word,
                'abbr': matches.group('abbr'),
                'menu': matches.group('menu')
            }
            if extended_autocomplete:
                sugg['info'] = matches.group('info').replace('<n>', "\n").strip()
            suggestions.append(sugg)

        return suggestions
