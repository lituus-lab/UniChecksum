# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniChecksum

func toBytes(s: string): seq[byte] =
  result = newSeq[byte](s.len)
  for i, c in s:
    result[i] = byte(c)

# CRC-64/XZ; "123456789" -> 0x995DC9BBDF1939FA is the catalogue check value.
const KnownCrc64 = [
  ("", 0x0000000000000000'u64),
  ("a", 0x330284772E652B05'u64),
  ("abc", 0x2CD8094A1A277627'u64),
  ("message digest", 0x5DBCC956318A9B6F'u64),
  ("123456789", 0x995DC9BBDF1939FA'u64),
  ("The quick brown fox jumps over the lazy dog", 0x5B5EB8C2E54AA1C4'u64),
]

suite "CRC-64/XZ":
  test "published check values":
    for (input, want) in KnownCrc64:
      check crc64(input) == want

  test "the catalogue check value is the one for this polynomial":
    check Crc64Polynomial == 0xC96C5795D7870F42'u64
    check crc64("123456789") == 0x995DC9BBDF1939FA'u64

  test "an empty span leaves the initial state untouched":
    let empty: seq[byte] = @[]
    check crc64(empty) == crc64Final(crc64Init())
    check crc64Update(crc64Init(), empty) == crc64Init()

  test "streaming byte by byte matches the one-shot call":
    let data = "The quick brown fox jumps over the lazy dog"
    var state = crc64Init()
    for c in data:
      state = crc64Update(state, byte(c))
    check crc64Final(state) == crc64(data)

  test "every split point gives the same checksum":
    let bytes = toBytes("123456789")
    for cut in 0 .. bytes.len:
      var state = crc64Update(crc64Init(), bytes.toOpenArray(0, cut - 1))
      state = crc64Update(state, bytes.toOpenArray(cut, bytes.len - 1))
      check crc64Final(state) == 0x995DC9BBDF1939FA'u64

  test "a single flipped bit changes the checksum":
    var data = toBytes("UniChecksum")
    let before = crc64(data)
    data[3] = data[3] xor 0x01'u8
    check crc64(data) != before

  test "a long buffer matches an external reference":
    var data = newSeq[byte](20000)
    for i in 0 ..< data.len:
      data[i] = byte((i * 7 + 3) mod 251)
    check crc64(data) == 0x873578D60D09CAE1'u64
