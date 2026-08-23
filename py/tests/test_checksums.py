# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""zlib is the independent oracle for CRC-32 and Adler-32; CRC-64/XZ has no
stdlib equivalent and is checked against published values."""
import array
import zlib

import pytest
import unichecksum

SAMPLES = [
    b"",
    b"a",
    b"abc",
    b"message digest",
    b"123456789",
    b"The quick brown fox jumps over the lazy dog",
    bytes(range(256)) * 40,
]

CRC64_KNOWN = {
    b"": 0x0000000000000000,
    b"a": 0x330284772E652B05,
    b"abc": 0x2CD8094A1A277627,
    b"message digest": 0x5DBCC956318A9B6F,
    b"123456789": 0x995DC9BBDF1939FA,
    b"The quick brown fox jumps over the lazy dog": 0x5B5EB8C2E54AA1C4,
}


def test_version():
    assert unichecksum.version() == "0.1.0"
    assert unichecksum.__version__ == "0.1.0"


@pytest.mark.parametrize("data", SAMPLES)
def test_crc32_matches_zlib(data):
    assert unichecksum.crc32(data) == zlib.crc32(data)


@pytest.mark.parametrize("data", SAMPLES)
def test_adler32_matches_zlib(data):
    assert unichecksum.adler32(data) == zlib.adler32(data)


@pytest.mark.parametrize("data,want", CRC64_KNOWN.items())
def test_crc64_known_values(data, want):
    assert unichecksum.crc64(data) == want


def test_crc64_check_value():
    assert unichecksum.crc64(b"123456789") == 0x995DC9BBDF1939FA


@pytest.mark.parametrize("fn", [unichecksum.crc32, unichecksum.crc64,
                                unichecksum.adler32])
def test_continuation_matches_one_shot(fn):
    whole = b"The quick brown fox jumps over the lazy dog"
    for cut in (0, 1, 10, len(whole) - 1, len(whole)):
        assert fn(whole[cut:], fn(whole[:cut])) == fn(whole)


def test_empty_input_identities():
    assert unichecksum.crc32(b"") == 0
    assert unichecksum.crc64(b"") == 0
    assert unichecksum.adler32(b"") == 1


@pytest.mark.parametrize("make", [
    bytes,
    bytearray,
    memoryview,
    lambda b: array.array("B", b),
])
def test_accepts_any_contiguous_buffer(make):
    data = b"123456789"
    assert unichecksum.crc32(make(data)) == 0xCBF43926


def test_non_contiguous_memoryview_falls_back_to_a_copy():
    # A strided slice raises BufferError on the zero-copy path.
    strided = memoryview(b"abcdef")[::2]
    assert not strided.c_contiguous
    assert unichecksum.crc32(strided) == zlib.crc32(b"ace")
    assert unichecksum.adler32(strided) == zlib.adler32(b"ace")


@pytest.mark.parametrize("bad", [5, 0, [1, 2], (1, 2), None, 3.5])
def test_non_buffer_data_is_rejected(bad):
    # bytes(5) would build five zero bytes and hand back a real checksum for
    # an argument that carries none.
    for fn in (unichecksum.crc32, unichecksum.crc64, unichecksum.adler32):
        with pytest.raises(TypeError):
            fn(bad)


def test_adler32_rejects_an_unreachable_state():
    for bad in (0xFFFFFFFF, 65521, 65521 << 16):
        with pytest.raises(ValueError):
            unichecksum.adler32(b"abc", bad)
    # The largest reachable state is accepted.
    unichecksum.adler32(b"abc", (65520 << 16) | 65520)


def test_str_is_rejected():
    with pytest.raises(TypeError):
        unichecksum.crc32("123456789")


@pytest.mark.parametrize("fn,bits", [(unichecksum.crc32, 32),
                                     (unichecksum.crc64, 64),
                                     (unichecksum.adler32, 32)])
def test_value_out_of_range(fn, bits):
    with pytest.raises(ValueError):
        fn(b"abc", -1)
    with pytest.raises(ValueError):
        fn(b"abc", 1 << bits)


def test_value_must_be_int():
    with pytest.raises(TypeError):
        unichecksum.crc32(b"abc", 1.0)
    with pytest.raises(TypeError):
        unichecksum.crc32(b"abc", True)


def test_constants_come_from_the_header():
    assert unichecksum.ADLER32_MODULUS == 65521
    assert unichecksum.CRC32_POLYNOMIAL == 0xEDB88320
    assert unichecksum.CRC64_POLYNOMIAL == 0xC96C5795D7870F42
