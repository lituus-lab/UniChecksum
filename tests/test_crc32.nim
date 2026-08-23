# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniChecksum

func toBytes(s: string): seq[byte] =
  result = newSeq[byte](s.len)
  for i, c in s:
    result[i] = byte(c)

# Values published in the CRC catalogue and reproduced by zlib.crc32.
const KnownCrc32 = [
  ("", 0x00000000'u32),
  ("a", 0xE8B7BE43'u32),
  ("abc", 0x352441C2'u32),
  ("message digest", 0x20159D7F'u32),
  ("123456789", 0xCBF43926'u32),
  ("The quick brown fox jumps over the lazy dog", 0x414FA339'u32),
]

suite "CRC-32":
  test "published check values":
    for (input, want) in KnownCrc32:
      check crc32(input) == want

  test "the catalogue check value is the one for this polynomial":
    check Crc32Polynomial == 0xEDB88320'u32
    check crc32("123456789") == 0xCBF43926'u32

  test "an empty span leaves the initial state untouched":
    let empty: seq[byte] = @[]
    check crc32(empty) == crc32Final(crc32Init())
    check crc32Update(crc32Init(), empty) == crc32Init()

  test "streaming byte by byte matches the one-shot call":
    let data = "The quick brown fox jumps over the lazy dog"
    var state = crc32Init()
    for c in data:
      state = crc32Update(state, byte(c))
    check crc32Final(state) == crc32(data)

  test "every split point gives the same checksum":
    let data = "123456789"
    let bytes = toBytes(data)
    for cut in 0 .. bytes.len:
      var state = crc32Update(crc32Init(), bytes.toOpenArray(0, cut - 1))
      state = crc32Update(state, bytes.toOpenArray(cut, bytes.len - 1))
      check crc32Final(state) == 0xCBF43926'u32

  test "a single flipped bit changes the checksum":
    var data = toBytes("UniChecksum")
    let before = crc32(data)
    data[3] = data[3] xor 0x01'u8
    check crc32(data) != before

  test "a long buffer matches an external reference":
    var data = newSeq[byte](20000)
    for i in 0 ..< data.len:
      data[i] = byte((i * 7 + 3) mod 251)
    check crc32(data) == 0xAB846D26'u32
