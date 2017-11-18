# -*- coding: utf-8 -*-
# For debugging, use this command to start neovim:
#
# NVIM_PYTHON_LOG_FILE=nvim.log NVIM_PYTHON_LOG_LEVEL=INFO nvim

import os, sys
PLUGIN_BASE_PATH = os.path.abspath("%s/../../../" % __file__)
sys.path.insert(0, PLUGIN_BASE_PATH)
from elixir_sense import ElixirSenseClient
import re

DEBUG = False

from cm import register_source, getLogger, Base
register_source(name='alchemist',
                priority=8,
                abbreviation='ex',
                scopes=['elixir'],
                cm_refresh_patterns=[r'\.'],)

logger = getLogger(__name__)

class Source(Base):
    def __init__(self, nvim):
        super(Source, self).__init__(nvim)
        self.re_suggestions = re.compile(r'kind:(?P<kind>[^,]*), word:(?P<word>[^,]*), abbr:(?P<abbr>[\w\W]*), menu:(?P<menu>[\w\W]*), info:(?P<info>[\w\W]*)$')
        self.re_is_only_func = re.compile(r'^[a-z]')

        alchemist_script = "%s/elixir_sense/run.exs" % PLUGIN_BASE_PATH
        self.sense_client = ElixirSenseClient(debug=DEBUG, cwd=os.getcwd(), ansi=False, elixir_sense_script=alchemist_script, elixir_otp_src="")

    def cm_refresh(self, info, ctx):
        lnum = self.nvim.funcs.line('.')
        cnum = self.nvim.funcs.col('.')
        lines = self.nvim.funcs.getline(1, '$')
        complete_str = ctx['typed']


        response = self.sense_client.process_command('suggestions', "\n".join(lines), lnum ,cnum)
        if response[0:6] == 'error:':
            logger.error("================= alchemist error: %s =====", response)
            self.nvim.command('echohl ErrorMsg|echom "%s"|echohl None' % response)
            return []

        startcol = ctx['startcol'] - len(complete_str)
        matches = self.__get_suggestions__(complete_str, response.split('\n')[:-1])
        self.complete(info, ctx, startcol, matches)

        return matches
    def __get_suggestions__(self, complete_str, server_results):
        suggestions = []
        for result in server_results:
            matches = self.re_suggestions.match(result)
            word = matches.group('word')
            kind = matches.group('kind')
            if  kind == "f" and self.re_is_only_func.match(complete_str):
                word = word.split(".")[-1]

            sugg = {
                'kind': kind,
                'word': word,
                'abbr': matches.group('abbr'),
                'menu': matches.group('menu'),
            }
            if self.nvim.funcs.exists('g:alchemist#extended_autocomplete'):
                if self.nvim.eval('g:alchemist#extended_autocomplete') == 1:
                    sugg['info'] = matches.group('info').replace("<n>", "\n").strip()
            suggestions.append(sugg)

        return suggestions
