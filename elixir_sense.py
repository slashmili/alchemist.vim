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
import errno

class ElixirSenseClient:


    def __init__(self, **kw):
        self._debug = kw.get('debug', False)
        self._cwd = kw.get('cwd', '')
        self.__create_tmp_dir()
        self._cwd = self.get_project_base_dir()
        self._ansi = kw.get('ansi', True)
        self._alchemist_script = kw.get('elixir_sense_script', None)
        self._elixir_otp_src = kw.get('elixir_otp_src', None)
        self.re_erlang_module = re.compile(r'^(?P<module>[a-z])')
        self.re_elixir_src = re.compile(r'.*(/elixir.*/lib.*)')
        self.re_erlang_src = re.compile(r'.*otp.*(/lib/.*\.erl)')
        self.sock = None


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

        sock = self.__get_socket()

        try:
            resp_erl_struct = self._send_command(sock, req_erl_struct)
        except Exception as e:
            return 'error:%s' % e

        rep_py_struct = erl_terms.decode(resp_erl_struct)
        if rep_py_struct['error']:
            return 'error:%s' % rep_py_struct['error']
        self._log('ElixirSense: %s' % rep_py_struct)
        if request == "suggestions":
            return self.to_vim_suggestions(rep_py_struct['payload'])
        elif request == "docs":
            if rep_py_struct['payload']['docs']:
                return rep_py_struct['payload']['docs']['docs']
            return rep_py_struct['payload']
        elif request == 'definition':
            return self.to_vim_definition(rep_py_struct['payload'])

    def __get_socket(self):
        if self.sock:
            return self.sock
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
        self.sock = sock
        return self.sock

    def to_vim_definition(self, source):
        filename = source.split(":")[0]

        if filename == "non_existing": return source
        if self._is_readable(filename): return source

        filename = self._find_elixir_erlang_src(filename)
        return "%s:%i" %(filename, 0)

    def to_vim_suggestions(self, suggestions):
        """
        >>> alchemist = ElixirSenseClient()
        >>> alchemist.to_vim_suggestions([{'type': 'hint', 'value': 'Enum.ma'}, {'origin': 'Enum', 'arity': 2, 'name': 'map', 'args': 'enumerable,fun', 'type': 'function', 'spec': '@spec map(t, (element -> any)) :: list', 'summary': 'Returns a list where each item is the result of invoking`fun` on each corresponding item of `enumerable`.'}])
        'kind:f, word:Enum.map, abbr:map(enumerable, fun), menu: Enum, info: @spec map(t, (element -> any)) :: list<n>Returns a list where each item is the result of invoking`fun` on each corresponding item of `enumerable`.\\n'
        >>> alchemist.to_vim_suggestions([{'type': 'hint', 'value': 'Cloud.Event'}, {'subtype': 'struct', 'type': 'module', 'name': 'Event', 'summary': ''}, {'subtype': None, 'type': 'module', 'name': 'EventBroadcaster', 'summary': ''}, {'subtype': None, 'type': 'module', 'name': 'EventConsumer', 'summary': ''}, {'subtype': None, 'type': 'module', 'name': 'EventService', 'summary': ''}])
        'kind:m, word:Cloud.Event, abbr:Event, menu: struct, info: \\nkind:m, word:Cloud.EventBroadcaster, abbr:EventBroadcaster, menu: module, info: \\nkind:m, word:Cloud.EventConsumer, abbr:EventConsumer, menu: module, info: \\nkind:m, word:Cloud.EventService, abbr:EventService, menu: module, info: \\n'
        >>> alchemist.to_vim_suggestions([{'type': 'hint', 'value': 'Mix.'}, {'subtype': None, 'type': 'module', 'name': 'Mix', 'summary': ''}, {'subtype': None, 'type': 'module', 'name': 'Ecto', 'summary': ''},{'origin': 'Mix', 'arity': 0, 'name': 'compilers', 'args': '', 'type': 'function', 'spec': '', 'summary': 'Returns the default compilers used by Mix.'}])
        'kind:m, word:Mix., abbr:Mix, menu: module, info: \\nkind:m, word:Mix.Ecto, abbr:Ecto, menu: module, info: \\nkind:f, word:Mix.compilers, abbr:compilers(), menu: Mix, info: Returns the default compilers used by Mix.\\n'
        >>> alchemist.to_vim_suggestions([{'type': 'hint', 'value': 'UserService.'}, {'subtype': None, 'type': 'module', 'name': 'UserService', 'summary': ''}, {'origin': 'interface.UserService', 'arity': 0, 'name': 'all_pending_users', 'args': '', 'type': 'function', 'spec': '', 'summary': 'returns all users that requested invitation'}])
        'kind:m, word:UserService., abbr:UserService, menu: module, info: \\nkind:f, word:UserService.all_pending_users, abbr:all_pending_users(), menu: interface.UserService, info: returns all users that requested invitation\\n'
        >>> alchemist.to_vim_suggestions([{'type': 'hint', 'value': ':gen_'}, {'subtype': None, 'type': 'module', 'name': 'gen_event', 'summary': ''}, {'subtype': None, 'type': 'module', 'name': 'gen_fsm', 'summary': ''}])
        'kind:m, word::gen_event, abbr::gen_event, menu: module, info: \\nkind:m, word::gen_fsm, abbr::gen_fsm, menu: module, info: \\n'
        >>> alchemist.to_vim_suggestions([{'type': 'hint', 'value': ':gen_server.'}, {'origin': ':gen_server', 'arity': 1, 'name': 'behaviour_info', 'args': '', 'type': 'function', 'spec': None, 'summary': ''}])
        'kind:f, word::gen_server.behaviour_info, abbr:behaviour_info/1, menu: :gen_server, info: \\n'
        >>> alchemist.to_vim_suggestions([{'type': 'hint', 'value': 'put_'}, {'origin': 'Plug.Conn', 'arity': 3, 'name': 'put_private', 'args': 'conn,key,value', 'type': 'function', 'spec': '@spec put_private(t, atom, term) :: t', 'summary': 'Assigns a new **private** key and value in the connection.'}])
        'kind:f, word:Plug.Conn.put_private, abbr:put_private(conn, key, value), menu: Plug.Conn, info: @spec put_private(t, atom, term) :: t<n>Assigns a new **private** key and value in the connection.\\n'
        >>> alchemist.to_vim_suggestions([{'type': 'hint', 'value': 'MyApp.Service.'}, {'subtype': None, 'type': 'module', 'name': 'Service', 'summary': ''}, {'origin': 'MyApp.Service', 'arity': 0, 'name': 'blank_capabilities', 'args': '', 'type': 'function', 'spec': '', 'summary': 'sum\\n'}])
        'kind:m, word:MyApp.Service., abbr:Service, menu: module, info: \\nkind:f, word:MyApp.Service.blank_capabilities, abbr:blank_capabilities(), menu: MyApp.Service, info: sum\\n'

        """
        result = ''
        prefix_module = ''
        hint = suggestions[0]
        if '.' in hint['value']:
            prefix_module = '.'.join(hint['value'].split('.')[:-1]) + '.'

        suggestions = sorted(suggestions[1:], key=lambda s : dict.get(s, 'name', ''))
        for s in suggestions:
            if s['type'] == 'hint':
                continue
            if s['type'] == 'module':
                mtype = s['subtype'] or s['type']
                if ('%s.' % s['name']) == prefix_module:
                    word = "%s" % (prefix_module)
                else:
                    if re.match(r'.*%s.$' %(s['name']), prefix_module):
                        word = prefix_module
                    else:
                        word = "%s%s" % (prefix_module, s['name'])
                if self.re_erlang_module.match(s['name']):
                    word = self.__erlang_pad(word)
                    s['name'] = self.__erlang_pad(s['name'])
                info = s['summary']
                result = "%s%s" % (result, self.__suggestion_line('m', word, s['name'], mtype, info))
            if s['type'] == 'function':
                if ('%s.' % s['origin'][((len(prefix_module) -1)*-1):]) == prefix_module:
                    word = '%s%s' % (prefix_module, s['name'])
                else:
                    word = '%s.%s' % (s['origin'], s['name'])
                if word[0] == ':':
                    args = '%s/%s' % (s['name'], s['arity'])
                else:
                    if s['args'] == None:
                        s['args'] = ''
                    args = '%s(%s)' % (s['name'], ", ".join(s['args'].split(',')))
                info = s['summary']
                if s['spec'] and s['summary'] != '':
                    info = '%s\n%s' % (s['spec'].strip(), s['summary'].strip())
                elif s['spec']:
                    info = s['spec'].strip()


                result = "%s%s" % (result, self.__suggestion_line('f', word, args, s['origin'], info))

        return result

    def __suggestion_line(self, kind, word, abbr, menu, info):
        info = info.strip().replace('\n', "<n>")
        return "kind:%s, word:%s, abbr:%s, menu: %s, info: %s\n" % (kind, word, abbr, menu, info)

    def __erlang_pad(self, module):
        if self.re_erlang_module.match(module):
            return ':%s' % module
        else:
            return module

    def _log(self, text):
        if self._debug == False:
            return

        f = open("/tmp/log.log", "a")
        f.write("%s\n" % text.encode('utf8'))
        f.close()

        #syslog.openlog("alchemist_client")
        #syslog.syslog(syslog.LOG_ALERT, text)

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
        try:
            if sock is None: raise Exception("Socket is not available.")
            sock.sendall(packed_data + cmd)
            return self._sock_readlines(sock)
        except socket.error as e:
            self.sock = None
            self._log("Exception in communicating with server: %s" % e)
            if e.errno == 35:
                raise Exception("reached 10 sec timeout, error:Resource temporarily unavailable")
            elif e.errno == errno.EPIPE:
                raise Exception("Lost connection to Server. Try again, error:Resource temporarily unavailable")
            else:
                raise e

        self._log("response for %s: %s" % (cmd.split(" ")[0], result.replace('\n', '\\n')))
        return ''

    def _find_elixir_erlang_src(self, filename):
        if self._is_readable(filename):
            return filename
        if self.re_elixir_src.match(filename):
            elixir_src_file = "%s/elixir/lib/%s" % (self._elixir_otp_src, self.re_elixir_src.match(filename).group(1))
            if self._is_readable(elixir_src_file):
                return os.path.realpath(elixir_src_file)
        elif self.re_erlang_src.match(filename):
            erlang_src_file = "%s/otp/%s" % (self._elixir_otp_src, self.re_erlang_src.match(filename).group(1))
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
