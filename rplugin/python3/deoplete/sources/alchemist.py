import os
import re
from numbers import Number
from subprocess import PIPE, Popen
import shlex
from .base import Base

class Source(Base):
    ALCHEMIST_CLIENT   = 'g:alchemist#alchemist_client'
    ALCHEMIST_COMPLETE = 'elixircomplete#auto_complete'

    def __init__(self, vim):
        Base.__init__(self, vim)

        self.name = 'alchemist'
        self.mark = '[alchemist]'
        self.filetypes = ['elixir']
        self.is_bytepos = False
        self.re_suggestions = re.compile(r'kind:(?P<kind>.*), word:(?P<word>.*), abbr:(?P<abbr>.*), menu:(?P<menu>.*), info:(?P<info>.*)$')

    def get_complete_position(self, context):
        return self.vim.call('elixircomplete#auto_complete', 1, '')

    def gather_candidates(self, context):
        lnum = self.vim.funcs.line('.')
        cnum = self.vim.funcs.col('.')
        lines = self.vim.funcs.getline(1, '$')
        client  = self.__get_client__()
        cwd_opt = '-d{0} -c{1} -l{2} --request=suggestions'.format(os.getcwd(), cnum, lnum)
        args = '%s %s' % (client, cwd_opt)
        with Popen(shlex.split(args), stdin=PIPE, stdout=PIPE) as proc:
            lines = "\n".join(lines)
            (results, x) = proc.communicate(input=lines.encode())
        results = results.decode()
        return self.__get_suggestions__(results.split('\n')[:-1])

    # Private implementation
    ########################

    def __get_client__(self):
        return self.vim.eval(self.ALCHEMIST_CLIENT)

    def __get_suggestions__(self, server_results):
        suggestions = []
        for result in server_results:
            matches = self.re_suggestions.match(result)
            sugg = {
                'kind': matches.group('kind'),
                'word': matches.group('word'),
                'abbr': matches.group('abbr'),
                'menu': matches.group('menu'),
            }
            if self.vim.funcs.exists('g:alchemist#extended_autocomplete'):
                if self.vim.eval('g:alchemist#extended_autocomplete') == 1:
                    sugg['info'] = matches.group('info').replace("<n>", "\n").strip()
            suggestions.append(sugg)

        return suggestions
