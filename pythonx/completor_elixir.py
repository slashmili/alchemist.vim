# -*- coding: utf-8 -*-

import os
import re
import sys
from completor import Completor, vim

PLUGIN_BASE_PATH = os.path.abspath("%s/../../" % __file__)
sys.path.insert(0, PLUGIN_BASE_PATH)
from elixir_sense import ElixirSenseClient

DEBUG = False
ALCHEMIST_SCRIPT = os.path.join(PLUGIN_BASE_PATH, 'elixir_sense/run.exs')
RE_SUGGESTIONS = re.compile(r'kind:(?P<kind>[^,]*), word:(?P<word>[^,]*), abbr:(?P<abbr>[\w\W]*), menu:(?P<menu>[\w\W]*), info:(?P<info>[\w\W]*)$')
RE_IS_ONLY_FUNC = re.compile(r'((^|\.|\s+)([a-z]\w*)|\w+\.)$')


class Alchemist(Completor):
    filetype = 'elixir'
    trigger = r'(\w{2}|\.\w?)$'
    sync = True

    def parse(self, base):
        sense_client = ElixirSenseClient(debug=DEBUG, cwd=os.getcwd(), ansi=False, elixir_sense_script=ALCHEMIST_SCRIPT, elixir_otp_src='')

        lnum, cnum = vim.current.window.cursor
        lines = "\n".join(vim.current.buffer[:])
        response = sense_client.process_command('suggestions', lines, lnum, cnum)

        if response[0:6] == 'error:':
            return []
        return self.__get_suggestions__(base, response.split("\n")[:-1])

    def __get_suggestions__(self, base, results):
        suggestions = []
        extended_autocomplete = bool(vim.vars.get('alchemist#extended_autocomplete'))

        for result in results:
            matches = RE_SUGGESTIONS.match(result)
            kind = matches.group('kind')
            word = matches.group('word')
            if kind == 'f' and RE_IS_ONLY_FUNC.search(base):
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


