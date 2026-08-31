# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/strutils
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "Streaming"

nbText: """
# Streaming

A checksum over a file that does not fit in memory, or over a socket that
arrives in pieces, cannot start from a single span. Every family here has the
same three-step shape: `Init` for the starting state, `Update` to fold bytes
in, `Final` to turn a state into a checksum.

Splitting the input changes nothing about the result.
"""

nbCode:
  import UniChecksum

  var state = crc32Init()
  state = crc32Update(state, "12345".toOpenArrayByte(0, 4))
  state = crc32Update(state, "6789".toOpenArrayByte(0, 3))
  echo "streamed ", crc32Final(state).toHex(8)
  echo "one-shot ", crc32("123456789").toHex(8)

nbText: """
## A state is not a checksum

The distinction matters, and nothing in the types enforces it: both are plain
integers. A running state is not a valid checksum until `Final` has run, and
folding more bytes into an already finalized value gives nonsense.
"""

nbCode:
  var running = crc32Init()
  running = crc32Update(running, "12345".toOpenArrayByte(0, 4))
  echo "the running state      ", running.toHex(8)
  echo "the checksum so far    ", crc32Final(running).toHex(8)
  echo "crc32(\"12345\")         ", crc32("12345").toHex(8)

nbText: """
The state and the checksum of the same bytes are different numbers. Storing the
first where the second belongs produces a value that compares unequal to every
correct implementation, including this one on the next run.

## Resuming from a finished value

`crc32Final` is a single XOR, so it is its own inverse: a finalized value can
be turned back into a state when a caller wants to continue from a result it
was handed rather than from bytes it still holds.
"""

nbCode:
  let firstHalf = crc32("12345")
  var resumed = crc32Final(firstHalf) # back to a state
  resumed = crc32Update(resumed, "6789".toOpenArrayByte(0, 3))
  echo "resumed  ", crc32Final(resumed).toHex(8)
  echo "one-shot ", crc32("123456789").toHex(8)

nbText: """
That is the property the Python binding exposes as a second argument, where
`crc32(b, crc32(a))` equals `crc32(a + b)` — the same shape `zlib.crc32` has,
so code written against the standard library moves across unchanged.

It is a property of these CRCs, not a general one. Do not assume it of a
checksum whose `Final` does more than XOR.
"""

nbSave
