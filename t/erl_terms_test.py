import erl_terms
import unittest


class Tests(unittest.TestCase):
    def test_basic_atom(self):
        hello = erl_terms._encode_atom('hello')
        self.assertEqual(hello, b'd\x00\x05hello')

        self.assertEqual(erl_terms._decode_atom(hello), "hello")

    def test_basic_boolean(self):
        true_term = erl_terms._encode_boolean(True)
        false_term = erl_terms._encode_boolean(False)
        self.assertEqual(true_term, b'd\x00\x04true')
        self.assertEqual(false_term, b'd\x00\x05false')

        self.assertEqual(erl_terms._decode_atom(true_term), True)
        self.assertEqual(erl_terms._decode_atom(false_term), False)

    def test_basic_int(self):
        int_1_term = erl_terms._encode_int(1)
        int_256_term = erl_terms._encode_int(256)
        self.assertEqual(int_1_term, b'a\x01')
        self.assertEqual(int_256_term, b'b\x00\x00\x01\x00')

        self.assertEqual(erl_terms._decode_int(int_1_term), 1)
        self.assertEqual(erl_terms._decode_int(int_256_term), 256)

    def test_basic_string(self):
        h_term = erl_terms._encode_string("h")
        hell_word_term = erl_terms._encode_string("hello world!")
        self.assertEqual(h_term, b'm\x00\x00\x00\x01h')
        self.assertEqual(hell_word_term, b'm\x00\x00\x00\x0chello world!')

        self.assertEqual(erl_terms._decode_string(h_term), "h")
        self.assertEqual(erl_terms._decode_string(hell_word_term), "hello world!")

    def test_basic_none(self):
        none_term = erl_terms._encode_none(None)
        self.assertEqual(none_term, b'd\x00\x03nil')

        self.assertEqual(erl_terms._decode_atom(none_term), None)

    def test_list(self):
        empty_list_term = erl_terms._encode_list([])
        one_item_string_list_term = erl_terms._encode_list(['a'])
        one_item_int_list_term = erl_terms._encode_list([1])
        mix_list_term = erl_terms._encode_list([1, 'a'])

        self.assertEqual(empty_list_term, b'j')
        self.assertEqual(one_item_string_list_term, b'l\x00\x00\x00\x01m\x00\x00\x00\x01aj')
        self.assertEqual(one_item_int_list_term, b'l\x00\x00\x00\x01a\x01j')
        self.assertEqual(mix_list_term, b'l\x00\x00\x00\x02a\x01m\x00\x00\x00\x01aj')

        self.assertEqual(erl_terms._decode_list(empty_list_term), [])
        self.assertEqual(erl_terms._decode_list(one_item_string_list_term), ['a'])
        self.assertEqual(erl_terms._decode_list(one_item_int_list_term), [1])
        self.assertEqual(erl_terms._decode_list(mix_list_term), [1, 'a'])

    def test_map(self):
        empty_map_term = erl_terms._encode_map({})
        foo_map_term = erl_terms._encode_map({'foo': 1})
        foo_bar_map_term = erl_terms._encode_map({'foo': 'bar'})
        inner_map_term = erl_terms._encode_map({'foo': {'bar': 4938}})
        inner_list_map_term = erl_terms._encode_map({'foo': {'list': [4938]}})



        self.assertEqual(empty_map_term, b't\x00\x00\x00\x00')
        self.assertEqual(foo_map_term, b't\x00\x00\x00\x01m\x00\x00\x00\x03fooa\x01')
        self.assertEqual(foo_bar_map_term, b't\x00\x00\x00\x01m\x00\x00\x00\x03foom\x00\x00\x00\x03bar')
        self.assertEqual(inner_map_term, b't\x00\x00\x00\x01m\x00\x00\x00\x03foot\x00\x00\x00\x01m\x00\x00\x00\x03barb\x00\x00\x13J')
        self.assertEqual(inner_list_map_term, b't\x00\x00\x00\x01m\x00\x00\x00\x03foot\x00\x00\x00\x01m\x00\x00\x00\x04listl\x00\x00\x00\x01b\x00\x00\x13Jj')

        self.assertEqual(erl_terms._decode_map(empty_map_term), {})
        self.assertEqual(erl_terms._decode_map(foo_map_term), {'foo': 1})
        self.assertEqual(erl_terms._decode_map(foo_bar_map_term), {'foo': 'bar'})
        self.assertEqual(erl_terms._decode_map(inner_map_term), {'foo': {'bar': 4938}})
        self.assertEqual(erl_terms._decode_map(inner_list_map_term), {'foo': {'list': [4938]}})


        complex_map = {'error': None, 'payload': {'active_param': 1, 'pipe_before': False}, 'signatures': [{'docs': 'docs', 'name': 'name', 'params': ['list']}, {'docs': 'snd doc', 'params': ['list']}], 'request_id': 1 }

        self.assertEqual(erl_terms._decode_map(erl_terms._encode_map(complex_map)), complex_map)

    def test_encode_decode(self):
        simple_erl_term = erl_terms.encode(1)
        self.assertEqual(simple_erl_term, b'\x83a\x01')
        self.assertEqual(erl_terms.decode(simple_erl_term), 1)

        complex_data = {'error': None, 'payload': {'active_param': 1, 'pipe_before': False}, 'signatures': [{'docs': 'docs', 'name': 'name', 'params': ['list']}, {'docs': 'snd doc', 'params': ['list']}], 'request_id': 1 }

        self.assertEqual(erl_terms.decode(erl_terms.encode(complex_data)), complex_data)

if __name__ == '__main__':
    unittest.main()
