# -*- coding: utf-8 -*-

import os
import sys
from argparse import ArgumentParser

PLUGIN_BASE_PATH = os.path.abspath("%s/../../../" % __file__)
sys.path.insert(0, PLUGIN_BASE_PATH)
from elixir_sense import ElixirSenseClient

DEBUG = False
ALCHEMIST_SCRIPT = os.path.join(PLUGIN_BASE_PATH, 'elixir_sense/run.exs')


def main():
    parser = ArgumentParser()
    parser.add_argument('--lnum', dest='lnum', type=int)
    parser.add_argument('--cnum', dest='cnum', type=int)
    parser.add_argument('--lines', dest='lines')
    args = parser.parse_args()

    sense_client = ElixirSenseClient(debug=DEBUG, cwd=os.getcwd(), ansi=False, elixir_sense_script=ALCHEMIST_SCRIPT, elixir_otp_src='')
    response = sense_client.process_command('suggestions', args.lines, args.lnum, args.cnum)

    if response[:6] != 'error:':
        sys.stdout.write(response)


if __name__ == '__main__':
    main()
