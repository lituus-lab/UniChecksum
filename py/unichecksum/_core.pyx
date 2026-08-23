# cython: language_level=3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
from libc.stdint cimport uint32_t, uint64_t

cdef extern from "UniChecksum.h":
    const char *unichecksum_version()
    # Header macros, read through Cython so the Python values cannot drift
    # from the C ones.
    const uint32_t UNICHECKSUM_CRC32_POLYNOMIAL
    const uint64_t UNICHECKSUM_CRC64_POLYNOMIAL
    const uint32_t UNICHECKSUM_ADLER32_MODULUS
    uint32_t unichecksum_crc32_update(uint32_t state, const unsigned char *data, size_t length)
    uint32_t unichecksum_crc32_final(uint32_t state)
    uint64_t unichecksum_crc64_update(uint64_t state, const unsigned char *data, size_t length)
    uint64_t unichecksum_crc64_final(uint64_t state)
    uint32_t unichecksum_adler32_update(uint32_t state, const unsigned char *data, size_t length)


# One dispatcher shape per family: read a contiguous buffer in place when the
# object exposes one, otherwise copy once into bytes. A non-contiguous
# memoryview raises BufferError, not TypeError, so it is caught here too.
def crc32(data, uint32_t value=0):
    """Raw C call. Use unichecksum.crc32."""
    # final() is its own inverse, so it turns a checksum back into a state.
    cdef uint32_t state = unichecksum_crc32_final(value)
    cdef const unsigned char[::1] view
    cdef bytes copied
    try:
        view = data
    except (TypeError, ValueError, BufferError):
        # memoryview() first: bytes(5) would quietly build five zero bytes and
        # return a checksum for an argument that carries none.
        copied = bytes(memoryview(data))
        view = copied
    if view.shape[0] > 0:
        state = unichecksum_crc32_update(state, &view[0], <size_t>view.shape[0])
    return unichecksum_crc32_final(state)


def crc64(data, uint64_t value=0):
    """Raw C call. Use unichecksum.crc64."""
    cdef uint64_t state = unichecksum_crc64_final(value)
    cdef const unsigned char[::1] view
    cdef bytes copied
    try:
        view = data
    except (TypeError, ValueError, BufferError):
        # memoryview() first: bytes(5) would quietly build five zero bytes and
        # return a checksum for an argument that carries none.
        copied = bytes(memoryview(data))
        view = copied
    if view.shape[0] > 0:
        state = unichecksum_crc64_update(state, &view[0], <size_t>view.shape[0])
    return unichecksum_crc64_final(state)


def adler32(data, uint32_t value=1):
    """Raw C call. Use unichecksum.adler32."""
    # Adler-32 has no output transform: the running value is already a state.
    cdef uint32_t state = value
    cdef const unsigned char[::1] view
    cdef bytes copied
    try:
        view = data
    except (TypeError, ValueError, BufferError):
        # memoryview() first: bytes(5) would quietly build five zero bytes and
        # return a checksum for an argument that carries none.
        copied = bytes(memoryview(data))
        view = copied
    if view.shape[0] > 0:
        state = unichecksum_adler32_update(state, &view[0], <size_t>view.shape[0])
    return state


def version():
    return unichecksum_version()


def constants():
    """(crc32 polynomial, crc64 polynomial, adler32 modulus) from the header."""
    return (UNICHECKSUM_CRC32_POLYNOMIAL,
            UNICHECKSUM_CRC64_POLYNOMIAL,
            UNICHECKSUM_ADLER32_MODULUS)
