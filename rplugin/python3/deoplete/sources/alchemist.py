import os, sys
PLUGIN_BASE_PATH = os.path.abspath("%s/../../../../../" % __file__)
sys.path.insert(0, PLUGIN_BASE_PATH)
from elixir_sense import ElixirSenseClient
import re
from .base import Base

DEBUG = False

class Source(Base):
    def __init__(self, vim):
        Base.__init__(self, vim)

        self.name = 'alchemist'
        self.mark = '[alchemist]'
        self.filetypes = ['elixir']
        self.is_bytepos = False
        self.re_suggestions = re.compile(r'kind:(?P<kind>[^,]*), word:(?P<word>[^,]*), abbr:(?P<abbr>[\w\W]*), menu:(?P<menu>[\w\W]*), info:(?P<info>[\w\W]*)$')
        self.re_is_only_func = re.compile(r'^[a-z]')

        alchemist_script = "%s/elixir_sense/run.exs" % PLUGIN_BASE_PATH
        self.sense_client = ElixirSenseClient(debug=DEBUG, cwd=os.getcwd(), ansi=False, elixir_sense_script=alchemist_script, elixir_otp_src="")

    def get_complete_position(self, context):
        return self.vim.call('elixircomplete#auto_complete', 1, '')

    def gather_candidates(self, context):
        lnum = self.vim.funcs.line('.')
        cnum = self.vim.funcs.col('.')
        lines = self.vim.funcs.getline(1, '$')
        complete_str = context['complete_str']

        response = self.sense_client.process_command('suggestions', "\n".join(lines), lnum ,cnum)
        if response[0:6] == 'error:':
            #self.vim.command('echohl ErrorMsg|echom "%s"|echohl None' % response)
            return []

        return self.__get_suggestions__(complete_str, response.split('\n')[:-1])

    # Private implementation
    ########################

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
            if self.vim.funcs.exists('g:alchemist#extended_autocomplete'):
                if self.vim.eval('g:alchemist#extended_autocomplete') == 1:
                    sugg['info'] = matches.group('info').replace("<n>", "\n").strip()
            suggestions.append(sugg)

        return suggestions
