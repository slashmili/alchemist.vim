from __future__ import print_function
import os
import tempfile
import re
import pprint
import subprocess, shlex
import select, socket
import time
import syslog

class AlchemistClient:


    def __init__(self, **kw):
        self._cwd = kw.get('cwd', '')
        self._ansi = kw.get('ansi', True)
        self._debug = kw.get('debug', False)
        self._alchemist_script = kw.get('alchemist_script', None)
        self.re_elixir_fun_with_arity = re.compile(r'(?P<func>.*)/[0-9]+$')
        self.re_erlang_module = re.compile(r'^\:(?P<module>.*)')
        self.re_elixir_module = re.compile(r'^(?P<module>[A-Z][A-Za-z0-9\._]+)')
        self.re_x_base = re.compile(r'^.*{\s*"(?P<base>.*)"\s*')


    def process_command(self, cmd, cmd_type=None):
        if cmd_type == None:
            cmd_type = cmd.split(" ")[0]
        server_log = self._get_running_server_log()
        if server_log == None:
            server_log = self._create_server_log()
            self._run_alchemist_server(server_log)

        connection = self._extract_connection_settings(server_log)
        if connection == None:
            self._run_alchemist_server(server_log)
            connection = self._extract_connection_settings(server_log)

        sock = self._connect(connection)
        if sock == None:
            self._run_alchemist_server(server_log)
            connection = self._extract_connection_settings(server_log)
            sock = self._connect(connection)

        if cmd_type == 'COMPX':
            result = self._send_compx(sock, cmd)
        elif cmd_type == 'DEFLX':
            result = self._send_deflx(sock, cmd)
        else:
            result = self._send_command(sock, cmd_type, cmd)

        return result

    def _log(self, text):
        if self._debug == False:
            return
        syslog.openlog("alchemist_client")
        syslog.syslog(syslog.LOG_ALERT, text)

    def _get_path_unique_name(self, path):
        """
        >>> alchemist = AlchemistClient()
        >>> alchemist._get_path_unique_name("/Users/milad/dev/ex_guard/")
        'zSUserszSmiladzSdevzSex_guard'
        """
        return os.path.abspath(path).replace("/", "zS")

    def _create_server_log(self):
        dir_tmp = self._get_tmp_dir()
        log_tmp = "%s/%s" % (dir_tmp, self._cwd.replace("/", "zS"))
        if os.path.exists(dir_tmp) == False:
            os.makedirs(dir_tmp)

        if os.path.exists(log_tmp) == False:
            return log_tmp

        return None

    def _get_running_server_log(self):
        dir_tmp = self._get_tmp_dir()
        log_tmp = "%s/%s" % (dir_tmp, self._get_path_unique_name(self._cwd))
        if os.path.exists(dir_tmp) == False:
            return None

        if os.path.exists(log_tmp) == True:
            return log_tmp

        return None

    def _run_alchemist_server(self, server_log):
        """
        execute alchemist server and wait until it has printed a line
        into STDOUT
        """
        alchemist_script = self._alchemist_script
        if os.path.exists(alchemist_script) == False:
            raise Exception("alchemist script does not exist in (%s)" % alchemist_script)
        alchemist_script = "elixir %s --env=dev --listen" % alchemist_script
        if self._ansi == False:
            alchemist_script = "%s --no-ansi" % alchemist_script
        #alchemist_script = "%s %s" % (alchemist_script, self._cwd)
        arg = shlex.split(alchemist_script)
        log_file = open(server_log, "w")
        subprocess.Popen(arg, stdout=log_file, stderr=log_file, cwd=self._cwd)
        for t in range(1, 5):
            time.sleep(t/10.1)
            if len(open(server_log).readlines()) > 0:
                break

    def _connect(self, host_port):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

        try:
            sock.connect(host_port)
        except socket.error as e:
            self._log("Can not establish connection to %s, error: %s" % (host_port, e))
            return None

        if self._is_connection_alive(sock) == False:
            sock.close()
            return None
        return sock

    def _is_connection_alive(self, sock):
        if self._send_command(sock, "PING", "PING") == "PONG\nEND-OF-PING\n":
            return True
        return False

    def _send_command(self, sock, cmd_type, cmd):
        sock.sendall("%s\n" % cmd)
        result = ''
        try:
            for line in self._sock_readlines(sock):
                result += "%s\n" % line
                if line.strip() == "END-OF-%s" % cmd_type: break
        except socket.error as e:
            if e.errno == 35:
                raise Exception("reached 10 sec timeout, error:Resource temporarily unavailable")
            else:
                raise e

        return result

    def _send_compx(self, sock, cmd):
        cmd_type = 'COMP'
        cmd = cmd.replace('COMPX', 'COMP')
        base_match = self.re_x_base.match(cmd)
        if base_match:
            base = base_match.group('base')
        result = self._send_command(sock, cmd_type, cmd)
        suggestions = filter(lambda x: x != 'END-OF-COMP', result.split("\n"))
        auto_completes = self.auto_complete(base, suggestions)
        r = []
        for ac in auto_completes:
            r.append("kind:%s, word:%s, abbr:%s" % (ac['kind'], ac['word'], ac['abbr']))
        r.append('END-OF-COMPX')
        return "\n".join(r)

    def _send_deflx(self, sock, cmd):
        cmd_type = 'DEFL'
        cmd = cmd.replace('DEFLX', 'DEFL')
        base_match = self.re_x_base.match(cmd)
        base = base_match.group('base')
        cmd = cmd.replace(base, self._defl_extract_module_func(base), 1)
        result = self._send_command(sock, cmd_type, cmd)
        result = result.replace('END-OF-DEFL', 'END-OF-DEFLX')
        return result

    def _defl_extract_module_func(self, query):
        """
        >>> alchemist = AlchemistClient()
        >>> alchemist._defl_extract_module_func("System")
        'System,nil'
        >>> alchemist._defl_extract_module_func("System.put_env")
        'System,put_env'
        >>> alchemist._defl_extract_module_func("ExGuard.Guard")
        'ExGuard.Guard,nil'
        >>> alchemist._defl_extract_module_func("ExGuard.Guard.guard")
        'ExGuard.Guard,guard'
        """
        func = 'nil'
        module = query
        func_match = re.compile(r'(?P<module>.*)\.(?P<func>[a-z_!?]+)$')
        match = func_match.match(query)
        if match:
            func = match.group('func')
            module = match.group('module')
        return '%s,%s' % (module, func)

    def _sock_readlines(self, sock, recv_buffer=4096, delim='\n', timeout=10):
        buffer = ''
        data = True
        sock.setblocking(0)
        while data:
            select.select([sock], [], [], timeout)
            data = sock.recv(recv_buffer)
            buffer += data

            while buffer.find(delim) != -1:
                line, buffer = buffer.split('\n', 1)
                yield line
        return

    def _extract_connection_settings(self, server_log):
        """
        >>> alchemist = AlchemistClient()
        >>> server_log = "t/fixtures/alchemist_server/valid.log"
        >>> print(alchemist._extract_connection_settings(server_log))
        ('localhost', 2433)

        >>> server_log = "t/fixtures/alchemist_server/invalid.log"
        >>> print(alchemist._extract_connection_settings(server_log))
        None
        """
        for line in open(server_log, "r").readlines():
            match = re.search(r'ok\|(?P<host>\w+):(?P<port>\d+)', line)
            if match:
                (host, port) = match.groups()
                return (host, int(port))
                break
        return None

    def _get_tmp_dir(self):
        """
        >>> alchemist = AlchemistClient()
        >>> os.environ['TMPDIR'] = '/tmp/foo01/'
        >>> alchemist._get_tmp_dir()
        '/tmp/foo01/alchemist_server'
        >>> del os.environ['TMPDIR']
        >>> os.environ['TEMP'] = '/tmp/foo02/'
        >>> alchemist._get_tmp_dir()
        '/tmp/foo02/alchemist_server'
        >>> del os.environ['TEMP']
        >>> os.environ['TMP'] = '/tmp/foo03/'
        >>> alchemist._get_tmp_dir()
        '/tmp/foo03/alchemist_server'
        >>> del os.environ['TMP']
        >>> alchemist._get_tmp_dir() == tempfile.tempdir #TODO: revert
        False
        """
        for var in ['TMPDIR', 'TEMP', 'TMP']:
            if var in os.environ:
                return os.path.abspath("%s/alchemist_server" % os.environ[var])
        if tempfile.tempdir != None:
            return os.path.abspath("%s/alchemist_server" % tempfile.tempdir)

        return "%s/alchemist_server" % "/tmp"

        pass

    def get_project_base_dir(self, running_servers_logs=None):
        """
        >>> #prepare the test env
        >>> tmp_dir = tempfile.mkdtemp()
        >>> p01_dir = os.path.join(tmp_dir, "p01")
        >>> os.mkdir(p01_dir)
        >>> p01_lib_dir = os.path.join(p01_dir, "lib")
        >>> os.mkdir(p01_lib_dir)
        >>> p01_log = p01_dir.replace("/", "zS")

        >>> #detect that base dir is already running
        >>> alchemist = AlchemistClient(cwd=p01_dir)
        >>> alchemist.get_project_base_dir([p01_log]) == p01_dir
        True
        >>> #since server is running on base dir, if lib dir is given, should return base dir
        >>> alchemist = AlchemistClient(cwd=p01_lib_dir)
        >>> alchemist.get_project_base_dir([p01_log]) == p01_dir
        True
        >>> #if given dir is out of base dir, should return the exact dir
        >>> alchemist = AlchemistClient(cwd=tmp_dir)
        >>> alchemist.get_project_base_dir([p01_log]) == tmp_dir
        True
        >>> #since there is no running server, lib dir is detected as base dir
        >>> alchemist = AlchemistClient(cwd=p01_lib_dir)
        >>> alchemist.get_project_base_dir([]) == p01_lib_dir
        True
        >>> #prepare mix test
        >>> open(os.path.join(p01_dir, "mix.exs"), 'a').close()
        >>> #should find mix.exs recursively and return base dir
        >>> alchemist = AlchemistClient(cwd=p01_lib_dir)
        >>> alchemist.get_project_base_dir([]) == p01_dir
        True
        """

        if running_servers_logs == None:
            running_servers_logs = os.listdir(self._get_tmp_dir())
        paths = self._cwd.split(os.sep)
        mix_dir = []
        for i in range(len(paths)):
            project_dir = os.sep.join(paths[:len(paths)-i])
            log_tmp = "%s" % project_dir.replace("/", "zS")
            if log_tmp in running_servers_logs:
                return project_dir

            if os.path.exists(os.path.join(project_dir, "mix.exs")):
                mix_dir.append(project_dir)

        if len(mix_dir):
            return mix_dir.pop(0)

        return self._cwd

    def auto_complete(self, base, suggestions):
        """
        >>> alchemist = AlchemistClient()
        >>> pprint.pprint(alchemist.auto_complete('Li', []))
        None
        >>> pprint.pprint(alchemist.auto_complete('Li', ['List.', 'Chars', 'first/1']))
        [{'abbr': 'List.', 'kind': 'm', 'word': 'List.'},
         {'abbr': 'Chars', 'kind': 'm', 'word': 'List.Chars.'},
         {'abbr': 'first/1', 'kind': 'f', 'word': 'List.first'}]
        >>> pprint.pprint(alchemist.auto_complete('L', ['L', 'List', 'Logger']))
        [{'abbr': 'List', 'kind': 'm', 'word': 'List.'},
         {'abbr': 'Logger', 'kind': 'm', 'word': 'Logger.'}]
        >>> pprint.pprint(alchemist.auto_complete('g', ['get_', 'get_in/2']))
        [{'abbr': 'get_in/2', 'kind': 'f', 'word': 'get_in'}]
        >>> pprint.pprint(alchemist.auto_complete('g', ['get_in/2', 'get_in', 'get_in/2']))
        [{'abbr': 'get_in/2', 'kind': 'f', 'word': 'get_in'}]
        >>> pprint.pprint(alchemist.auto_complete('List.f', ['List.f', 'first/1', 'flatten/1']))
        [{'abbr': 'first/1', 'kind': 'f', 'word': 'List.first'},
         {'abbr': 'flatten/1', 'kind': 'f', 'word': 'List.flatten'}]
        >>> pprint.pprint(alchemist.auto_complete(':gen', [':gen', 'gen', 'gen_event']))
        [{'abbr': ':gen', 'kind': 'm', 'word': ':gen'},
         {'abbr': ':gen_event', 'kind': 'm', 'word': ':gen_event'}]
        >>> pprint.pprint(alchemist.auto_complete(':g', [':g', 'gb_sets', 'gb_trees', 'global']))
        [{'abbr': ':gb_sets', 'kind': 'm', 'word': ':gb_sets'},
         {'abbr': ':gb_trees', 'kind': 'm', 'word': ':gb_trees'},
         {'abbr': ':global', 'kind': 'm', 'word': ':global'}]
        >>> pprint.pprint(alchemist.auto_complete(':gen_server.', [':gen_server.', 'behaviour_info/1', 'module_info/0']))
        [{'abbr': ':gen_server.', 'kind': 'm', 'word': ':gen_server.'},
         {'abbr': 'behaviour_info/1',
          'kind': 'f',
          'word': ':gen_server.behaviour_info'},
         {'abbr': 'module_info/0', 'kind': 'f', 'word': ':gen_server.module_info'}]
        """
        if len(suggestions) == 0: return None
        return_list = []
        first_item = suggestions[0]
        if suggestions[0][-1] != '.':
            suggestions.pop(0)
        for sug in suggestions:
            if len(sug) == 0:
                continue
            if self.re_elixir_fun_with_arity.match(sug):
                return_list.append(self.func_auto_complete(base, suggestions[0], sug))
            elif self.re_elixir_module.match(sug):
                return_list.append(self.elixir_mod_auto_complete(base, suggestions[0], sug))
            elif self.re_erlang_module.match(first_item):
                return_list.append(self.erlang_mod_auto_complete(base, suggestions[0], sug))


        return return_list

    def func_auto_complete(self, base, first, suggestion):
        """
        >>> alchemist = AlchemistClient()
        >>> pprint.pprint(alchemist.func_auto_complete("Li", "List.", "first/1"))
        {'abbr': 'first/1', 'kind': 'f', 'word': 'List.first'}
        >>> pprint.pprint(alchemist.func_auto_complete("List.f", "List.first", "first/1"))
        {'abbr': 'first/1', 'kind': 'f', 'word': 'List.first'}
        >>> pprint.pprint(alchemist.func_auto_complete("g", "get_", "get_in/2"))
        {'abbr': 'get_in/2', 'kind': 'f', 'word': 'get_in'}
        """
        func_dict = {'kind': 'f', 'abbr': suggestion}
        func_name = self.re_elixir_fun_with_arity.match(suggestion).group('func')
        word = "%s%s" % (first, func_name)

        func_parts = base.split('.')
        if len(func_parts) > 1:
            word = ".".join(func_parts[:len(func_parts)-1])
            word = "%s.%s" % (word, func_name)
        elif first[-1] != '.':
            word = func_name

        func_dict['word'] = word
        return func_dict

    def erlang_mod_auto_complete(self, base, first, suggestion):
        """
        >>> alchemist = AlchemistClient()
        >>> pprint.pprint(alchemist.erlang_mod_auto_complete(':gen', ':gen', 'gen'))
        {'abbr': ':gen', 'kind': 'm', 'word': ':gen'}
        >>> #pprint.pprint(alchemist.erlang_mod_auto_complete(':g', ':g', 'gb_sets'))
        """
        #TODO: to check case: :gen.^X^O => base ":gen." ==> :gen.
        if suggestion[0] != ':':
            suggestion = ':%s' % suggestion
        mod_dict = {'kind': 'm', 'abbr': suggestion}
        mod_dict['word'] = suggestion

        return mod_dict

    def elixir_mod_auto_complete(self, base, first, suggestion):
        """
        >>> alchemist = AlchemistClient()
        >>> pprint.pprint(alchemist.elixir_mod_auto_complete('Li', 'List.', 'List.'))
        {'abbr': 'List.', 'kind': 'm', 'word': 'List.'}
        >>> pprint.pprint(alchemist.elixir_mod_auto_complete('Li', 'List.', 'Chars'))
        {'abbr': 'Chars', 'kind': 'm', 'word': 'List.Chars.'}
        >>> pprint.pprint(alchemist.elixir_mod_auto_complete('L', 'L', 'List'))
        {'abbr': 'List', 'kind': 'm', 'word': 'List.'}
        """
        mod_dict = {'kind': 'm', 'abbr': suggestion}
        if first == suggestion:
            mod_dict['word'] = '%s.' % suggestion.strip('.')
        elif first[-1] == '.':
            mod_dict['word'] = "%s%s." % (first, suggestion)
        else:
            mod_dict['word'] = '%s.' % suggestion

        return mod_dict




if __name__ == "__main__":
    import doctest
    doctest.testmod()
