# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# Run by book/surfaces.nim during the book build; its output is the page's.
# A file rather than `python3 -c`: the snippet needs both quote characters, and
# nesting them through Nim and then the shell is how a block ends up green and
# wrong.
import unichecksum as u

print("crc32(b'123456789')    =", hex(u.crc32(b"123456789")))
print("adler32(b'123456789')  =", hex(u.adler32(b"123456789")))
print("crc32(b'6789', crc32(b'12345')) =",
      hex(u.crc32(b"6789", u.crc32(b"12345"))))
print("crc32(b'123456789')             =", hex(u.crc32(b"123456789")))

for bad in ("a str", None):
    try:
        u.crc32(bad)
    except (TypeError, ValueError) as exc:
        print(f"  crc32({bad!r}) -> {type(exc).__name__}: {exc}")
try:
    u.crc32(b"x", -1)
except (TypeError, ValueError) as exc:
    print(f"  crc32(b'x', -1) -> {type(exc).__name__}: {exc}")
