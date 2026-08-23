# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniChecksum

func toBytes(s: string): seq[byte] =
  result = newSeq[byte](s.len)
  for i, c in s:
    result[i] = byte(c)

# Values reproduced by zlib.adler32.
const KnownAdler32 = [
  ("", 0x00000001'u32),
  ("a", 0x00620062'u32),
  ("abc", 0x024D0127'u32),
  ("message digest", 0x29750586'u32),
  ("123456789", 0x091E01DE'u32),
  ("The quick brown fox jumps over the lazy dog", 0x5BDC0FDA'u32),
]

suite "Adler-32":
  test "published check values":
    for (input, want) in KnownAdler32:
      check adler32(input) == want

  test "an empty span leaves the initial state untouched":
    let empty: seq[byte] = @[]
    check adler32(empty) == adler32Init()
    check adler32Update(adler32Init(), empty) == adler32Init()

  test "the final transform is the identity":
    for (input, want) in KnownAdler32:
      check adler32Final(adler32(input)) == want

  test "streaming byte by byte matches the one-shot call":
    let data = "The quick brown fox jumps over the lazy dog"
    var state = adler32Init()
    for c in data:
      state = adler32Update(state, byte(c))
    check adler32Final(state) == adler32(data)

  test "every split point gives the same checksum":
    let bytes = toBytes("123456789")
    for cut in 0 .. bytes.len:
      var state = adler32Update(adler32Init(), bytes.toOpenArray(0, cut - 1))
      state = adler32Update(state, bytes.toOpenArray(cut, bytes.len - 1))
      check adler32Final(state) == 0x091E01DE'u32

  test "both halves stay below the modulus":
    var data = newSeq[byte](20000)
    for i in 0 ..< data.len:
      data[i] = byte((i * 7 + 3) mod 251)
    let state = adler32(data)
    check (state and 0xFFFF'u32) < Adler32Modulus
    check (state shr 16) < Adler32Modulus

  test "the deferred modulo matches a byte-at-a-time fold":
    # Longer than one reduction chunk, so the span path and the byte path
    # exercise different code.
    var data = newSeq[byte](20000)
    for i in 0 ..< data.len:
      data[i] = byte((i * 7 + 3) mod 251)
    var slow = adler32Init()
    for b in data:
      slow = adler32Update(slow, b)
    check adler32(data) == adler32Final(slow)

  test "a long buffer matches an external reference":
    var data = newSeq[byte](20000)
    for i in 0 ..< data.len:
      data[i] = byte((i * 7 + 3) mod 251)
    check adler32(data) == 0x7E812527'u32

  test "a state above the modulus violates the precondition":
    # Compiled away under -d:release, where the check cannot fire at all.
    when not defined(release):
      expect Defect:
        discard adler32Update(0xFFFFFFFF'u32, byte('a'))
