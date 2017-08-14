from __future__ import print_function
import os
import tempfile
import re
import pprint
import subprocess, shlex
import select, socket
import time
import syslog
import struct
import erl_terms

class ElixirSenseClient:


    def __init__(self, **kw):
        self._debug = kw.get('debug', False)
        self._cwd = kw.get('cwd', '')
        self.__create_tmp_dir()
        self._cwd = self.get_project_base_dir()
        self._ansi = kw.get('ansi', True)
        self._alchemist_script = kw.get('elixir_sense_script', None)
        self._source = kw.get('source', None)
        self.re_elixir_fun_with_arity = re.compile(r'(?P<func>.*)/[0-9]+$')
        self.re_elixir_module_and_fun = re.compile(r'^(?P<module>[A-Z][A-Za-z0-9\._]+)\.(?P<func>[a-z_?!]+)')
        self.re_erlang_module = re.compile(r'^\:(?P<module>.*)')
        self.re_elixir_module = re.compile(r'^(?P<module>[A-Z][A-Za-z0-9\._]+)')
        self.re_x_base = re.compile(r'^.*{\s*"(?P<base>.*)"\s*')
        self.re_elixir_src = re.compile(r'.*(/lib/elixir/lib.*)')
        self.re_erlang_src = re.compile(r'.*otp.*(/lib/.*\.erl)')


    def __create_tmp_dir(self):
        dir_tmp = self._get_tmp_dir()
        if os.path.exists(dir_tmp) == False:
            os.makedirs(self._get_tmp_dir())
    def process_command(self, request, source, line, column):
        self._log('column: %s' % column)
        self._log('line: %s' % line)
        self._log('source: %s' % source)
        py_struct = {
                'request_id': 1,
                'auth_token': None,
                'request': request,
                'payload': {
                    'buffer': source,
                    'line': int(line),
                    'column': int(column)
                    }
                }

        req_erl_struct = erl_terms.encode(py_struct)
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
            if connection == None:
                self._log("Couldn't find the connection settings from server_log: %s" % (server_log))
                return  None
            sock = self._connect(connection)

        resp_erl_struct = self._send_command(sock, req_erl_struct)
        #f = open("/tmp/erl_bin.txt", "wb")
        #f.write(resp_erl_struct)
        rep_py_struct = erl_terms.decode(resp_erl_struct)
        self._log('ElixirSense: %s' % rep_py_struct)
        if request == "suggestions":
            return self.to_vim_suggestions(rep_py_struct['payload'])
        elif request == "docs":
            if rep_py_struct['payload']['docs']:
                return rep_py_struct['payload']['docs']['docs']
            return rep_py_struct['payload']
        elif request == 'definition':
            return rep_py_struct['payload']

    def to_vim_suggestions(self, suggestions):
        """
        >>> alchemist = ElixirSenseClient()
        >>> alchemist.to_vim_suggestions([{'type': 'hint', 'value': 'Enum.ma'}, {'origin': 'Enum', 'arity': 2, 'name': 'map', 'args': 'enumerable,fun', 'type': 'function', 'spec': '@spec map(t, (element -> any)) :: list', 'summary': 'Returns a list where each item is the result of invoking`fun` on each corresponding item of `enumerable`.'}])
        'kind:f, word:Enum.map, abbr:map(enumerable,fun), menu: Enum\\n'
        >>> alchemist.to_vim_suggestions([{'type': 'hint', 'value': 'Cloud.Event'}, {'subtype': 'struct', 'type': 'module', 'name': 'Event', 'summary': ''}, {'subtype': None, 'type': 'module', 'name': 'EventBroadcaster', 'summary': ''}, {'subtype': None, 'type': 'module', 'name': 'EventConsumer', 'summary': ''}, {'subtype': None, 'type': 'module', 'name': 'EventService', 'summary': ''}])
        'kind:m, word:Cloud.Event, abbr:Event, menu: struct\\nkind:m, word:Cloud.EventBroadcaster, abbr:EventBroadcaster, menu: module\\nkind:m, word:Cloud.EventConsumer, abbr:EventConsumer, menu: module\\nkind:m, word:Cloud.EventService, abbr:EventService, menu: module\\n'
        >>> alchemist.to_vim_suggestions([{'type': 'hint', 'value': 'Mix.'}, {'subtype': None, 'type': 'module', 'name': 'Mix', 'summary': ''}, {'subtype': None, 'type': 'module', 'name': 'Ecto', 'summary': ''},{'origin': 'Mix', 'arity': 0, 'name': 'compilers', 'args': '', 'type': 'function', 'spec': '', 'summary': 'Returns the default compilers used by Mix.'}])
        'kind:m, word:Mix., abbr:Mix, menu: module\\nkind:m, word:Mix.Ecto, abbr:Ecto, menu: module\\nkind:f, word:Mix.compilers, abbr:compilers(), menu: Mix\\n'
        >>> alchemist.to_vim_suggestions([{'type': 'hint', 'value': 'UserService.'}, {'subtype': None, 'type': 'module', 'name': 'UserService', 'summary': ''}, {'origin': 'Interface.UserService', 'arity': 0, 'name': 'all_pending_users', 'args': '', 'type': 'function', 'spec': '', 'summary': 'Returns all users that requested invitation'}])
        'kind:m, word:UserService., abbr:UserService, menu: module\\nkind:f, word:UserService.all_pending_users, abbr:all_pending_users(), menu: Interface.UserService\\n'
        """
        result = ''
        prefix_module = ''
        for s in suggestions:
            if s['type'] == 'hint':
                if '.' in s['value']:
                    prefix_module = '.'.join(s['value'].split('.')[:-1]) + '.'
                continue
            if s['type'] == 'module':
                mtype = s['subtype'] or s['type']
                if ('%s.' % s['name']) == prefix_module:
                    result = "%skind:%s, word:%s, abbr:%s, menu: %s\n" % (result, 'm', prefix_module, s['name'], mtype)
                else:
                    result = "%skind:%s, word:%s%s, abbr:%s, menu: %s\n" % (result, 'm', prefix_module, s['name'], s['name'], mtype)
            if s['type'] == 'function':
                args = '%s(%s)' % (s['name'], s['args'])
                if ('%s.' % s['origin'][((len(prefix_module) -1)*-1):]) == prefix_module:
                    result = "%skind:%s, word:%s%s, abbr:%s, menu: %s\n" % (result, 'f', prefix_module, s['name'], args, s['origin'])
                else:
                    result = "%skind:%s, word:%s.%s, abbr:%s, menu: %s\n" % (result, 'f', s['origin'], s['name'], args, s['origin'])

        return result

    def _log(self, text):
        f = open("/tmp/log.log", "a")
        f.write("%s\n" % text)
        f.close()

        if self._debug == False:
            return
        syslog.openlog("alchemist_client")
        syslog.syslog(syslog.LOG_ALERT, text)

    def _get_path_unique_name(self, path):
        """
        >>> alchemist = ElixirSenseClient()
        >>> alchemist._get_path_unique_name("/Users/milad/dev/ex_guard/")
        'zS2UserszS2miladzS2devzS2ex_guard'
        """
        return os.path.abspath(path).replace("/", "zS2")

    def _create_server_log(self):
        dir_tmp = self._get_tmp_dir()
        log_tmp = "%s/%s" % (dir_tmp, self._cwd.replace("/", "zS2"))
        if os.path.exists(dir_tmp) == False:
            os.makedirs(dir_tmp)

        if os.path.exists(log_tmp) == False:
            return log_tmp

        return None

    def _get_running_server_log(self):
        dir_tmp = self._get_tmp_dir()
        log_tmp = "%s/%s" % (dir_tmp, self._get_path_unique_name(self._cwd))
        self._log("Load server settings from: %s" % (log_tmp))
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
        alchemist_script = "elixir %s unix 0 dev" % alchemist_script
        self._log(alchemist_script)
        arg = shlex.split(alchemist_script)
        log_file = open(server_log, "w")
        subprocess.Popen(arg, stdout=log_file, stderr=log_file, stdin=log_file, cwd=self._cwd)
        for t in range(0, 50):
            time.sleep(0.1)
            r = open(server_log).readlines()
            if len(r) > 0:
                break

    def _connect(self, host_port):
        if host_port == None: return None
        (host, port) = host_port
        if isinstance(port, str):
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            host_port = port
        else:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

        try:
            sock.connect(host_port)
        except socket.error as e:
            self._log("Can not establish connection to %s, error: %s" % (host_port, e))
            return None

        return sock

    def _send_command(self, sock, cmd):
        packer = struct.Struct('!I')
        packed_data = packer.pack(len(cmd))
        sock.sendall(packed_data + cmd)
        try:
            return self._sock_readlines(sock)
        except socket.error as e:
            if e.errno == 35:
                raise Exception("reached 10 sec timeout, error:Resource temporarily unavailable")
            else:
                raise e

        self._log("response for %s: %s" % (cmd.split(" ")[0], result.replace('\n', '\\n')))
        return ''

    def _find_elixir_erlang_src(self, filename):
        if self._is_readable(filename):
            return filename
        if self.re_elixir_src.match(filename):
            elixir_src_file = "%s/elixir/%s" % (self._source, self.re_elixir_src.match(filename).group(1))
            if self._is_readable(elixir_src_file):
                return os.path.realpath(elixir_src_file)
        elif self.re_erlang_src.match(filename):
            erlang_src_file = "%s/otp/%s" % (self._source, self.re_erlang_src.match(filename).group(1))
            if self._is_readable(erlang_src_file):
                return os.path.realpath(erlang_src_file)
        return filename

    def _find_module_line(self, filename, module):
        return self._find_pattern_in_file(
                filename,
                ["defmodule %s" % module, "-module(%s)." % module[1:]])

    def _find_function_line(self, filename, function):
        return self._find_pattern_in_file(
                filename,
                ["def %s" % function, "defp %s" % function, "-spec %s" % function])

    def _find_pattern_in_file(self, filename, patterns):
        if not os.path.isfile(filename) or not os.access(filename, os.R_OK):
            return 1
        lines = open(filename, "r").readlines()
        for line_num, line_str in enumerate(lines):
            matched_p = list(filter(lambda p: p in line_str, patterns))
            if len(matched_p) > 0:
                return line_num + 1
        return 1

    def _is_readable(self, filename):
        if os.path.isfile(filename) and os.access(filename, os.R_OK):
            return True
        return False

    def _sock_readlines(self, sock, recv_buffer=4096, timeout=10):
        sock.setblocking(0)
        packet_size = -1

        select.select([sock], [], [], timeout)
        data = sock.recv(recv_buffer)
        (packet_size, ) = struct.unpack('!I', data[:4])
        buf = data[4:]
        while len(buf) < packet_size:
            select.select([sock], [], [], timeout)
            data = sock.recv(recv_buffer)
            buf = buf + data
        return buf

    def _extract_connection_settings(self, server_log):
        """
        >>> alchemist = ElixirSenseClient()
        >>> server_log = "t/fixtures/alchemist_server/valid.log"
        >>> print(alchemist._extract_connection_settings(server_log))
        ('localhost', '/tmp/elixir-sense-1502654288590225000.sock')

        >>> server_log = "t/fixtures/alchemist_server/invalid.log"
        >>> print(alchemist._extract_connection_settings(server_log))
        None
        """
        for line in open(server_log, "r").readlines():
            self._log(line)
            match = re.search(r'ok\:(?P<host>\w+):(?P<port>.*\.sock)', line)
            if match:
                (host, port) = match.groups()
                try :
                    return (host, int(port))
                except :
                    return (host, port)
        return None

    def _get_tmp_dir(self):
        """
        >>> alchemist = ElixirSenseClient()
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
        >>> p01_log = p01_dir.replace("/", "zS2")

        >>> #detect that base dir is already running
        >>> alchemist = ElixirSenseClient(cwd=p01_dir)
        >>> alchemist.get_project_base_dir([p01_log]) == p01_dir
        True
        >>> #since server is running on base dir, if lib dir is given, should return base dir
        >>> alchemist = ElixirSenseClient(cwd=p01_lib_dir)
        >>> alchemist.get_project_base_dir([p01_log]) == p01_dir
        True
        >>> #if given dir is out of base dir, should return the exact dir
        >>> alchemist = ElixirSenseClient(cwd=tmp_dir)
        >>> alchemist.get_project_base_dir([p01_log]) == tmp_dir
        True
        >>> #since there is no running server, lib dir is detected as base dir
        >>> alchemist = ElixirSenseClient(cwd=p01_lib_dir)
        >>> alchemist.get_project_base_dir([]) == p01_lib_dir
        True
        >>> #prepare mix test
        >>> open(os.path.join(p01_dir, "mix.exs"), 'a').close()
        >>> #should find mix.exs recursively and return base dir
        >>> alchemist = ElixirSenseClient(cwd=p01_lib_dir)
        >>> alchemist.get_project_base_dir([]) == p01_dir
        True
        >>> #find directory of parent when running inside a nested project
        >>> apps = os.path.join(p01_dir, "apps")
        >>> os.mkdir(apps)
        >>> nested = os.path.join(apps, "nested_project")
        >>> os.mkdir(nested)
        >>> nested_lib = os.path.join(nested, "lib")
        >>> os.mkdir(nested_lib)
        >>> open(os.path.join(nested, "mix.exs"), 'a').close()
        >>> alchemist = ElixirSenseClient(cwd=nested_lib)
        >>> alchemist.get_project_base_dir([]) == p01_dir
        True
        """

        if running_servers_logs == None:
            running_servers_logs = os.listdir(self._get_tmp_dir())
        paths = self._cwd.split(os.sep)
        mix_dir = []
        for i in range(len(paths)):
            project_dir = os.sep.join(paths[:len(paths)-i])
            if not project_dir:
                continue
            log_tmp = "%s" % project_dir.replace("/", "zS2")
            if log_tmp in running_servers_logs:
                self._log("project_dir(matched): "+str(project_dir))
                return project_dir

            if os.path.exists(os.path.join(project_dir, "mix.exs")):
                mix_dir.append(project_dir)

        self._log("mix_dir: "+str(mix_dir))
        if len(mix_dir):
            return mix_dir.pop()

        return self._cwd

if __name__ == "__main__":
    import doctest
    doctest.testmod()