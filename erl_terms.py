# -*- coding: utf-8 -*-

import struct
#def encode(py_struct):

__EXPORTS__ = [
    'decode',
    'encode',
]

FORMAT_VERSION = '\x83' #struct.pack("b", 131)

NEW_FLOAT_EXT = 70      # [Float64:IEEE float]
BIT_BINARY_EXT = 77     # [UInt32:Len, UInt8:Bits, Len:Data]
SMALL_INTEGER_EXT = struct.pack("b", 97)  # [UInt8:Int]
INTEGER_EXT = struct.pack("b", 98)        # [Int32:Int]
FLOAT_EXT = 99          # [31:Float String] Float in string format (formatted "%.20e", sscanf "%lf"). Superseded by NEW_FLOAT_EXT
ATOM_EXT = struct.pack("b", 100)          # 100 [UInt16:Len, Len:AtomName] max Len is 255
REFERENCE_EXT = 101     # 101 [atom:Node, UInt32:ID, UInt8:Creation]
PORT_EXT = 102          # [atom:Node, UInt32:ID, UInt8:Creation]
PID_EXT = 103           # [atom:Node, UInt32:ID, UInt32:Serial, UInt8:Creation]
SMALL_TUPLE_EXT = 104   # [UInt8:Arity, N:Elements]
LARGE_TUPLE_EXT = 105   # [UInt32:Arity, N:Elements]
NIL_EXT = struct.pack("b", 106)           # empty list
STRING_EXT = 107        # [UInt32:Len, Len:Characters]
LIST_EXT = struct.pack("b", 108)          # [UInt32:Len, Elements, Tail]
BINARY_EXT = struct.pack("b", 109)        # [UInt32:Len, Len:Data]
SMALL_BIG_EXT = 110     # [UInt8:n, UInt8:Sign, n:nums]
LARGE_BIG_EXT = 111     # [UInt32:n, UInt8:Sign, n:nums]
NEW_FUN_EXT = 112       # [UInt32:Size, UInt8:Arity, 16*Uint6-MD5:Uniq, UInt32:Index, UInt32:NumFree, atom:Module, int:OldIndex, int:OldUniq, pid:Pid, NunFree*ext:FreeVars]
EXPORT_EXT = 113        # [atom:Module, atom:Function, smallint:Arity]
NEW_REFERENCE_EXT = 114 # [UInt16:Len, atom:Node, UInt8:Creation, Len*UInt32:ID]
SMALL_ATOM_EXT = 115    # [UInt8:Len, Len:AtomName]
MAP_EXT = struct.pack("b", 116)
FUN_EXT = 117           # [UInt4:NumFree, pid:Pid, atom:Module, int:Index, int:Uniq, NumFree*ext:FreeVars]
COMPRESSED = 80         # [UInt4:UncompressedSize, N:ZlibCompressedData]

try:
    xrange
except NameError:
    xrange = range

def decode(binary):
    """
        >>> decode(b'\\x83' + SMALL_INTEGER_EXT + b'\x01')
        1
        >>> decode(b'\\x83\\x74\\x00\\x00\\x00\\x01\\x64\\x00\\x05\\x65\\x72\\x72\\x6F\\x72\\x64\\x00\\x03\\x6E\\x69\\x6c')
        {'error': None}
        >>> decode(encode(-256))
        -256
        >>> decode(encode(False))
        False
        >>> decode(encode(True))
        True
        >>> decode(encode(None))
        >>> decode(encode("Hello"))
        'Hello'
        >>> decode(encode([]))
        []
        >>> decode(encode([1]))
        [1]
        >>> decode(encode(['a']))
        ['a']
    """
    if binary[0] not in [b'\x83', 131]:
        raise NotImplementedError("Unable to serialize version %s" % binary[0])
    binary = binary[1:]

    (obj_size, fn) = _decode_func(binary)
    return fn(binary[0: obj_size])

def _decode_func(binary):
    if _data_type(binary[0]) == SMALL_INTEGER_EXT:
        return (2, _decode_int)
    elif _data_type(binary[0]) == INTEGER_EXT:
        return (5, _decode_int)
    elif _data_type(binary[0]) == BINARY_EXT:
        (size, ) = struct.unpack(">L", binary[1:5])
        return (1 + 4 + size, _decode_string)
    elif _data_type(binary[0]) == ATOM_EXT:
        (size, ) = struct.unpack(">H", binary[1:3])
        return (1 + 2 + size, _decode_atom)
    elif _data_type(binary[0]) == NIL_EXT:
        return (1, _decode_list)
    elif _data_type(binary[0]) == LIST_EXT:
        (list_size, ) = struct.unpack(">L", binary[1:5])
        tmp_binary = binary[5:]
        byte_size = 0
        for i in xrange(list_size):
            (obj_size, fn) = _decode_func(tmp_binary)
            byte_size = byte_size + obj_size
            tmp_binary = tmp_binary[obj_size:]
        return (1 + 4 + byte_size + 1, _decode_list)
    elif _data_type(binary[0]) == MAP_EXT:
        (map_size, ) = struct.unpack(">L", binary[1:5])
        tmp_binary = binary[5:]
        byte_size = 0
        for i in xrange(map_size):
            (obj_size, fn) = _decode_func(tmp_binary)
            byte_size = byte_size + obj_size
            tmp_binary = tmp_binary[obj_size:]


            (obj_size, fn) = _decode_func(tmp_binary)
            byte_size = byte_size + obj_size
            tmp_binary = tmp_binary[obj_size:]
        return (1 + 4 + byte_size , _decode_map)
    else:
        raise NotImplementedError("Unable to unserialize %r" % _data_type(binary[0]))

def _decode_map(binary):
    """
        >>> _decode_map(_encode_map({'foo': 1}))
        {'foo': 1}
        >>> _decode_map(_encode_map({'foo': 'bar'}))
        {'foo': 'bar'}
        >>> _decode_map(_encode_map({'foo': {'bar': 4938}}))
        {'foo': {'bar': 4938}}
    """
    (size,) = struct.unpack(">L", binary[1:5])
    result = {}
    binary = binary[5:]
    for i in xrange(size):

        (key_obj_size, key_fn) = _decode_func(binary)
        key = key_fn(binary[0: key_obj_size])
        binary = binary[key_obj_size:]

        (value_obj_size, value_fn) = _decode_func(binary)
        value = value_fn(binary[0: value_obj_size])

        binary = binary[value_obj_size:]

        result.update({key: value})

    return result


def _decode_list(binary):
    """
        >>> _decode_list(_encode_list([]))
        []
        >>> _decode_list(_encode_list(['a']))
        ['a']
        >>> _decode_list(_encode_list([1]))
        [1]
        >>> _decode_list(_encode_list([1, 'a']))
        [1, 'a']
        >>> _decode_list(_encode_list([True, None, 1, 'a']))
        [True, None, 1, 'a']
    """
    if binary == NIL_EXT: return []
    (size, ) = struct.unpack(">L", binary[1:5])
    result = []
    binary = binary[5:]
    for i in xrange(size):
        (obj_size, fn) = _decode_func(binary)
        result.append(fn(binary[0: obj_size]))
        binary = binary[obj_size:]

    return result

def _decode_string(binary):
    """
        >>> _decode_string(_encode_string("h"))
        'h'
    """
    return binary[5:].decode('UTF-8')

def _decode_atom(binary):
    """
        >>> _decode_atom(_encode_atom("nil"))
        >>> _decode_atom(_encode_atom("true"))
        True
        >>> _decode_atom(_encode_atom("false"))
        False
        >>> _decode_atom(_encode_atom("my_key"))
        'my_key'
    """
    atom = binary[3:]
    if atom == b'true':
        return True
    elif atom == b'false':
        return False
    elif atom == b'nil':
        return None
    return atom.decode('UTF-8')

def _decode_int(binary):
    """
        >>> _decode_int(_encode_int(1))
        1
        >>> _decode_int(_encode_int(256))
        256
    """
    if binary[0] == 97 or binary[0] == 'a' :
        if type(binary[1]) == int:
            return binary[1]
        else:
            (num,) = struct.unpack("B", binary[1])
            return num
    (num,) = struct.unpack(">l", binary[1:])
    return num

def encode(struct):
    """
        >>> encode(False)
        b'\\x83d\\x00\\x05false'
        >>> encode([])
        b'\\x83j'
    """
    return b'\x83' + _encoder_func(struct)(struct)

def _encode_list(obj):
    """
        >>> _encode_list([])
        b'j'
        >>> _encode_list(['a'])
        b'l\\x00\\x00\\x00\\x01m\\x00\\x00\\x00\\x01aj'
        >>> _encode_list([1])
        b'l\\x00\\x00\\x00\\x01a\\x01j'
    """
    if len(obj) == 0:
        return NIL_EXT
    b = struct.pack(">L", len(obj))
    for i in obj:
        b = b + _encoder_func(i)(i)
    return LIST_EXT + b + NIL_EXT

def _encode_map(obj):
    """
        >>> _encode_map({'foo': 1})
        b't\\x00\\x00\\x00\\x01m\\x00\\x00\\x00\\x03fooa\\x01'
        >>> _encode_map({'foo': 'bar'})
        b't\\x00\\x00\\x00\\x01m\\x00\\x00\\x00\\x03foom\\x00\\x00\\x00\\x03bar'
        >>> _encode_map({'foo': {'bar': 4938}})
        b't\\x00\\x00\\x00\\x01m\\x00\\x00\\x00\\x03foot\\x00\\x00\\x00\\x01m\\x00\\x00\\x00\\x03barb\\x00\\x00\\x13J'
    """
    b = struct.pack(">L", len(obj))
    for k,v in obj.items():
        b = b + _encoder_func(k)(k) +  _encoder_func(v)(v)
    return MAP_EXT + b

def _encoder_func(obj):
    if isinstance(obj, str):
        return _encode_string
    elif isinstance(obj, bool):
        return _encode_boolean
    elif isinstance(obj, int):
        return _encode_int
    elif isinstance(obj, dict):
        return _encode_map
    elif isinstance(obj, list):
        return _encode_list
    elif obj is None:
        return _encode_none
    else:
        raise NotImplementedError("Unable to serialize %r" % obj)

def _encode_string(obj):
    """
        >>> _encode_string("h")
        b'm\\x00\\x00\\x00\\x01h'
        >>> _encode_string("hello world!")
        b'm\\x00\\x00\\x00\\x0chello world!'
        >>> _encode_string("测试")
        b'm\x00\x00\x00\x06\xe6\xb5\x8b\xe8\xaf\x95'
    """
    str_enc = obj.encode('utf-8')
    return BINARY_EXT + struct.pack(">L", len(str_enc)) + str_enc

def _encode_none(obj):
    """
        >>> _encode_none(None)
        b'd\\x00\\x03nil'
    """
    return _encode_atom("nil")

def _encode_boolean(obj):
    """
        >>> _encode_boolean(True)
        b'd\\x00\\x04true'
        >>> _encode_boolean(False)
        b'd\\x00\\x05false'
    """
    if obj == True:
        return _encode_atom("true")
    elif obj == False:
        return _encode_atom("false")
    else:
        raise "Maybe later"

def _encode_atom(obj):
    return ATOM_EXT + struct.pack(">H", len(obj)) + obj.encode('utf-8')

def _encode_int(obj):
    """
        >>> _encode_int(1)
        b'a\\x01'
        >>> _encode_int(256)
        b'b\\x00\\x00\\x01\\x00'
    """
    if 0 <= obj <= 255:
        return SMALL_INTEGER_EXT +  struct.pack("B", obj)
    elif -2147483648 <= obj <= 2147483647:
        return INTEGER_EXT + struct.pack(">l", obj)
    else:
        raise "Maybe later"

def _data_type(dtype):
    if type(dtype) == int:
        return struct.pack("b", dtype)
    return dtype


if __name__ == "__main__":
    import doctest
    doctest.testmod()
    #f = open('/tmp/erl_bin.txt', 'rb')
    #data = f.read()
    #print(len(data))
    #print(decode(data))
