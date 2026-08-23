# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/strutils
import UniChecksum

echo "UniChecksum " & UniChecksumVersion
let samples = ["", "a", "abc", "123456789"]
for s in samples:
  echo "\"" & s & "\""
  echo "  crc32   " & crc32(s).toHex(8)
  echo "  crc64   " & crc64(s).toHex(16)
  echo "  adler32 " & adler32(s).toHex(8)

# Streaming: fold the same bytes in two pieces, get the same checksum.
var state = crc32Init()
state = crc32Update(state, "12345".toOpenArrayByte(0, 4))
state = crc32Update(state, "6789".toOpenArrayByte(0, 3))
echo "streamed crc32(\"123456789\") = " & crc32Final(state).toHex(8)
