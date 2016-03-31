import os
from numbers import Number
from subprocess import PIPE, Popen
from .base import Base

class Source(Base):
    ALCHEMIST_CLIENT   = 'g:alchemist#alchemist_client'
    ALCHEMIST_FORMAT   = 'alchemist#alchemist_format'
    ALCHEMIST_COMPLETE = 'elixircomplete#Complete'

    def __init__(self, vim):
        Base.__init__(self, vim)

        self.name = 'alchemist'
        self.mark = '[alchemist]'
        self.filetypes = ['elixir']
        self.is_bytepos = False
        self.min_pattern_length = 0

    def get_complete_position(self, context):
        return self.vim.call('elixircomplete#Complete', 1, '')

    def gather_candidates(self, context):
        client  = self.__get_client__()
        request = self.__get_request__(context['complete_str']).encode()
        cwd_opt = '-d{0}'.format(os.getcwd())

        with Popen([client, cwd_opt], stdin=PIPE, stdout=PIPE) as proc:
            results = proc.communicate(input=request)[0].decode()

        return self.__get_suggestions__(results.split('\n')[:-2])

    # Private implementation
    ########################

    def __get_client__(self):
        return self.vim.eval(self.ALCHEMIST_CLIENT)

    def __get_request__(self, input):
        return self.vim.call(self.ALCHEMIST_FORMAT, 'COMP', input, 'Elixir', [], [])

    def __get_suggestions__(self, server_results):
        suggestions = self.vim.call(self.ALCHEMIST_COMPLETE, 0, server_results)
        return [] if isinstance(suggestions, Number) else suggestions
