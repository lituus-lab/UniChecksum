# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniChecksum

suite "umbrella API":
  test "the version constant is stated at all":
    # That it agrees with the manifest, the header and the wheel is
    # tests/test_version.nim's job; a literal here would break on every bump.
    check UniChecksumVersion.len > 0

  test "the string and byte-span overloads agree":
    let text = "UniChecksum"
    var data = newSeq[byte](text.len)
    for i, c in text:
      data[i] = byte(c)
    check crc32(text) == crc32(data)
    check crc64(text) == crc64(data)
    check adler32(text) == adler32(data)

  test "each family exposes the same init/update/final shape":
    let data = [byte('a'), byte('b'), byte('c')]
    check crc32Final(crc32Update(crc32Init(), data)) == crc32(data)
    check crc64Final(crc64Update(crc64Init(), data)) == crc64(data)
    check adler32Final(adler32Update(adler32Init(), data)) == adler32(data)

  test "the three families disagree on the same input":
    # Guards against one family being wired to another's table.
    let data = "123456789"
    check crc32(data) != adler32(data)
    check uint64(crc32(data)) != crc64(data)
