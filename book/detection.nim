# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/strutils
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "What each one detects"

nbText: """
# What each one detects

Three checksums in one library invites the question the API cannot answer:
which one. The honest answer is that they detect different damage at different
cost, and the container formats that use them each made that trade already.

## What Adler-32 gives up

Adler-32 is two running sums modulo 65521 rather than a polynomial division.
What it gives up is detection strength, and that shows up most on short inputs,
where the two sums have barely moved apart.
"""

nbCode:
  import UniChecksum

  # Two short inputs one byte apart in one position.
  echo "adler32(\"ab\") ", adler32("ab").toHex(8)
  echo "adler32(\"ac\") ", adler32("ac").toHex(8)
  echo "crc32(\"ab\")   ", crc32("ab").toHex(8)
  echo "crc32(\"ac\")   ", crc32("ac").toHex(8)

nbText: """
Both change, but only one of them changes predictably. Raising an input byte by
one raises the low half by one, and the high half by one along with it, so the
packed Adler-32 value moves by exactly `0x00010001`. The two CRC-32 results
share nothing.
"""

nbCode:
  let moved = adler32("ac") - adler32("ab")
  echo "the difference ", moved.toHex(8), "  = 0x00010001: ", moved == 0x00010001'u32

nbText: """
zlib accepts that trade: its Adler-32 covers the whole uncompressed stream at
once, so it only has to catch damage somewhere in a large body. PNG validates
each chunk on its own, often just a few bytes, and uses a CRC-32 for it.

## The modulus is deferred, not applied per byte

The reduction modulo 65521 is expensive relative to an addition, so it is done
as rarely as correctness allows: up to 5552 bytes are summed before either half
is reduced, that being the largest number of maximal bytes that cannot overflow
32 bits along the way. Both halves stay below the modulus at every point a
caller can observe.
"""

nbCode:
  var data = newSeq[byte](20000)
  for i in 0 ..< data.len:
    data[i] = byte((i * 7 + 3) mod 251)
  let packed = adler32(data)
  echo "low  half ", packed and 0xFFFF'u32, " < ", Adler32Modulus
  echo "high half ", packed shr 16, " < ", Adler32Modulus

nbText: """
## Choosing

| | width | what it is | where it is used |
|---|---|---|---|
| Adler-32 | 32 | two sums mod 65521 | zlib stream trailer |
| CRC-32 | 32 | polynomial division | PNG chunks, gzip, ZIP |
| CRC-64/XZ | 64 | polynomial division | the `.xz` container |

Read a format's specification and use what it names — a checksum written into a
container is part of that container's grammar, not a choice the writer gets to
make. Where the choice is genuinely yours, and the data is short, the CRCs
detect more for the same call.

None of the three is a substitute for a cryptographic hash. If the threat is
someone changing the data on purpose, none of these helps: the checksum is
recomputed as easily as it is checked.

## References

- [Cyclic redundancy check](https://en.wikipedia.org/wiki/Cyclic_redundancy_check)
  — the polynomial-division construction and the reflected/initial/final
  parameters that distinguish one CRC from another.
- [Adler-32](https://en.wikipedia.org/wiki/Adler-32) — the two-sum construction
  and its weakness on short messages.
- [RFC 1950](https://www.rfc-editor.org/rfc/rfc1950), section 9 — the normative
  Adler-32 definition, including the reference implementation zlib ships.
- [ECMA-182](https://ecma-international.org/publications-and-standards/standards/ecma-182/),
  annex B — the 64-bit polynomial CRC-64/XZ uses.
- [PNG specification](https://www.w3.org/TR/png/#5CRC-algorithm), section 5 —
  CRC-32 as a chunk integrity check, with the same parameters used here.
- Philip Koopman, [CRC catalogue](https://users.ece.cmu.edu/~koopman/crc/) —
  published check values and detection properties per polynomial.
"""

nbSave
