# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/strutils
import lituus_theme

nbInit(theme = useNimibook)
useLituus()
nb.title = "UniChecksum"

nbText: """
# UniChecksum

Three checksums that container formats rely on to notice corruption: **CRC-32**
(zlib, PNG, gzip, ZIP), **CRC-64/XZ** (the `.xz` container), and **Adler-32**
(the zlib stream trailer). None of them is a cryptographic hash: they detect
accidental damage — a flipped bit, a truncated transfer — and an attacker who
can rewrite the data can always rewrite the checksum to match.

Every Nim block in this book is compiled and run when the book is built, and
the output shown is what the code produced. A change that breaks the API breaks
the docs build, so the two cannot drift.

## One call for a whole buffer

The umbrella module re-exports all three families. Each takes a byte span, or a
string when that reads better.
"""

nbCode:
  import UniChecksum

  echo "version ", UniChecksumVersion
  echo "crc32   ", crc32("123456789").toHex(8)
  echo "crc64   ", crc64("123456789").toHex(16)
  echo "adler32 ", adler32("123456789").toHex(8)

nbText: """
`"123456789"` is the input every CRC catalogue publishes a check value for,
which is what makes it the first thing to try against a new implementation:
CRC-32 must give `CBF43926` and CRC-64/XZ must give `995DC9BBDF1939FA`. Getting
those two right pins down the polynomial, the bit ordering, and both the
initial and final values at once.

## Empty input is not zero for Adler-32

The three families disagree on the empty span, and the disagreement is not an
accident of implementation — it falls out of each definition.
"""

nbCode:
  let nothing: seq[byte] = @[]
  echo "crc32   ", crc32(nothing).toHex(8)
  echo "crc64   ", crc64(nothing).toHex(16)
  echo "adler32 ", adler32(nothing).toHex(8)

nbText: """
A CRC starts at all-ones and ends by inverting, so with nothing folded in
between the two cancel and the result is zero. Adler-32 starts its low half at
one and never transforms its output, so the empty span keeps that one.

Treating "checksum is zero" as "no checksum computed" is therefore safe for the
CRCs and wrong for Adler-32. It is the kind of assumption that survives every
test written against real data and fails on the first empty file.
"""

nbSave
