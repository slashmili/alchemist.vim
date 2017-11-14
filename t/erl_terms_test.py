import sys, os
sys.path.insert(0, os.path.abspath("%s/../../" % __file__))

import unittest
from nose.tools import assert_equals
import erl_terms


def test_basic_atom():
    hello = erl_terms.__encode_atom('hello')
    assert_equals(hello, b'd\x00\x05hello')

    assert_equals(erl_terms.__decode_atom(hello), "hello")

def test_basic_boolean():
    true_term = erl_terms.__encode_boolean(True)
    false_term = erl_terms.__encode_boolean(False)
    assert_equals(true_term, b'd\x00\x04true')
    assert_equals(false_term, b'd\x00\x05false')

    assert_equals(erl_terms.__decode_atom(true_term), True)
    assert_equals(erl_terms.__decode_atom(false_term), False)

def test_basic_int():
    int_1_term = erl_terms.__encode_int(1)
    int_256_term = erl_terms.__encode_int(256)
    assert_equals(int_1_term, b'a\x01')
    assert_equals(int_256_term, b'b\x00\x00\x01\x00')

    assert_equals(erl_terms.__decode_int(int_1_term), 1)
    assert_equals(erl_terms.__decode_int(int_256_term), 256)

def test_basic_string():
    h_term = erl_terms.__encode_string("h")
    hell_word_term = erl_terms.__encode_string("hello world!")
    assert_equals(h_term, b'm\x00\x00\x00\x01h')
    assert_equals(hell_word_term, b'm\x00\x00\x00\x0chello world!')

    assert_equals(erl_terms.__decode_string(h_term), "h")
    assert_equals(erl_terms.__decode_string(hell_word_term), "hello world!")

def test_basic_none():
    none_term = erl_terms.__encode_none(None)
    assert_equals(none_term, b'd\x00\x03nil')

    assert_equals(erl_terms.__decode_atom(none_term), None)

def test_list():
    empty_list_term = erl_terms.__encode_list([])
    one_item_string_list_term = erl_terms.__encode_list(['a'])
    one_item_int_list_term = erl_terms.__encode_list([1])
    mix_list_term = erl_terms.__encode_list([1, 'a'])

    assert_equals(empty_list_term, b'j')
    assert_equals(one_item_string_list_term, b'l\x00\x00\x00\x01m\x00\x00\x00\x01aj')
    assert_equals(one_item_int_list_term, b'l\x00\x00\x00\x01a\x01j')
    assert_equals(mix_list_term, b'l\x00\x00\x00\x02a\x01m\x00\x00\x00\x01aj')

    assert_equals(erl_terms.__decode_list(empty_list_term), [])
    assert_equals(erl_terms.__decode_list(one_item_string_list_term), ['a'])
    assert_equals(erl_terms.__decode_list(one_item_int_list_term), [1])
    assert_equals(erl_terms.__decode_list(mix_list_term), [1, 'a'])

def test_map():
    empty_map_term = erl_terms.__encode_map({})
    foo_map_term = erl_terms.__encode_map({'foo': 1})
    foo_bar_map_term = erl_terms.__encode_map({'foo': 'bar'})
    inner_map_term = erl_terms.__encode_map({'foo': {'bar': 4938}})
    inner_list_map_term = erl_terms.__encode_map({'foo': {'list': [4938]}})



    assert_equals(empty_map_term, b't\x00\x00\x00\x00')
    assert_equals(foo_map_term, b't\x00\x00\x00\x01m\x00\x00\x00\x03fooa\x01')
    assert_equals(foo_bar_map_term, b't\x00\x00\x00\x01m\x00\x00\x00\x03foom\x00\x00\x00\x03bar')
    assert_equals(inner_map_term, b't\x00\x00\x00\x01m\x00\x00\x00\x03foot\x00\x00\x00\x01m\x00\x00\x00\x03barb\x00\x00\x13J')
    assert_equals(inner_list_map_term, b't\x00\x00\x00\x01m\x00\x00\x00\x03foot\x00\x00\x00\x01m\x00\x00\x00\x04listl\x00\x00\x00\x01b\x00\x00\x13Jj')

    assert_equals(erl_terms.__decode_map(empty_map_term), {})
    assert_equals(erl_terms.__decode_map(foo_map_term), {'foo': 1})
    assert_equals(erl_terms.__decode_map(foo_bar_map_term), {'foo': 'bar'})
    assert_equals(erl_terms.__decode_map(inner_map_term), {'foo': {'bar': 4938}})
    assert_equals(erl_terms.__decode_map(inner_list_map_term), {'foo': {'list': [4938]}})


    complex_map = {'error': None, 'payload': {'active_param': 1, 'pipe_before': False}, 'signatures': [{'docs': 'docs', 'name': 'name', 'params': ['list']}, {'docs': 'snd doc', 'params': ['list']}], 'request_id': 1 }

    assert_equals(erl_terms.__decode_map(erl_terms.__encode_map(complex_map)), complex_map)

def test_encode_decode():
    simple_erl_term = erl_terms.encode(1)
    assert_equals(simple_erl_term, b'\x83a\x01')
    assert_equals(erl_terms.decode(simple_erl_term), 1)

    complex_data = {'error': None, 'payload': {'active_param': 1, 'pipe_before': False}, 'signatures': [{'docs': 'docs', 'name': 'name', 'params': ['list']}, {'docs': 'snd doc', 'params': ['list']}], 'request_id': 1 }

    assert_equals(erl_terms.decode(erl_terms.encode(complex_data)), complex_data)

if __name__ == '__main__':
    import erl_terms
    print(erl_terms.__encode_boolean(True))
    #unittest.main()
