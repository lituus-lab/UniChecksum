# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""unichecksum — Python binding over the UniChecksum C library."""
from ._core import (
    adler32 as _adler32_c,
    constants as _constants_c,
    crc32 as _crc32_c,
    crc64 as _crc64_c,
    version as _version_c,
)

__version__ = _version_c().decode("ascii")

#: Read from UniChecksum.h, so these cannot drift from the C library.
CRC32_POLYNOMIAL, CRC64_POLYNOMIAL, ADLER32_MODULUS = _constants_c()


def crc32(data, value=0):
    """CRC-32 (IEEE 802.3) of `data` as an unsigned int.

    `data` is any bytes-like object; a contiguous buffer is read in place.
    `value` continues an earlier result, so ``crc32(b, crc32(a))`` equals
    ``crc32(a + b)``. Raises TypeError on a non-bytes-like `data`, ValueError
    on a `value` outside [0, 2**32).
    """
    return _crc32_c(data, _checked(data, value, 32))


def crc64(data, value=0):
    """CRC-64/XZ of `data` as an unsigned int.

    Same calling convention as `crc32`; `value` must fit in [0, 2**64).
    """
    return _crc64_c(data, _checked(data, value, 64))


def adler32(data, value=1):
    """Adler-32 (RFC 1950) of `data` as an unsigned int.

    Same calling convention as `crc32`, but the empty input is 1, not 0.
    `value` must be a state this function could have returned: both 16-bit
    halves below ADLER32_MODULUS.
    """
    state = _checked(data, value, 32)
    if (state & 0xFFFF) >= ADLER32_MODULUS or (state >> 16) >= ADLER32_MODULUS:
        raise ValueError(
            f"value is not a reachable Adler-32 state: {state:#010x}")
    return _adler32_c(data, state)


def _checked(data, value, bits):
    """Reject a str, and a running value no checksum of this width produced."""
    if data is None or isinstance(data, str):
        # Both reach the C layer as an empty span otherwise, so they would come
        # back as the checksum of nothing rather than as an error.
        raise TypeError(
            f"data must be bytes-like, not {type(data).__name__}")
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeError(f"value must be int, got {type(value).__name__}")
    if not 0 <= value < (1 << bits):
        raise ValueError(f"value must be in [0, 2**{bits}), got {value}")
    return value


def version():
    """C library version string."""
    return _version_c().decode("ascii")


__all__ = [
    "ADLER32_MODULUS",
    "CRC32_POLYNOMIAL",
    "CRC64_POLYNOMIAL",
    "__version__",
    "adler32",
    "crc32",
    "crc64",
    "version",
]
